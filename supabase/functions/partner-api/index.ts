import { withSupabase } from 'npm:@supabase/server'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

function hex(buffer: ArrayBuffer) {
  return Array.from(new Uint8Array(buffer))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('')
}

async function hmac(keyBytes: Uint8Array, message: string) {
  const key = await crypto.subtle.importKey(
    'raw',
    keyBytes,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  return new Uint8Array(
    await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(message)),
  )
}

async function validateTelegramInitData(initData: string, botToken: string) {
  const params = new URLSearchParams(initData)
  const receivedHash = params.get('hash')
  const authDate = Number(params.get('auth_date') ?? 0)
  if (!receivedHash || !authDate) throw new Error('Invalid Telegram session.')

  const age = Math.floor(Date.now() / 1000) - authDate
  if (age < -60 || age > 86400) throw new Error('Telegram session expired.')

  const checkString = [...params.entries()]
    .filter(([key]) => key !== 'hash')
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([key, value]) => key + '=' + value)
    .join('\n')

  const secretKey = await hmac(new TextEncoder().encode('WebAppData'), botToken)
  const calculated = hex(await hmac(secretKey, checkString))
  if (calculated !== receivedHash) {
    throw new Error('Telegram session validation failed.')
  }

  const userRaw = params.get('user')
  if (!userRaw) throw new Error('Telegram user information is missing.')
  return JSON.parse(userRaw) as {
    id: number
    first_name?: string
    last_name?: string
    username?: string
  }
}

async function membership(admin: any, telegramUserId: string) {
  const { data, error } = await admin
    .from('partner_business_members')
    .select('business_id, role, businesses(*)')
    .eq('telegram_user_id', telegramUserId)
  if (error) throw error
  return data ?? []
}

function response(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

const bookingStatuses = ['requested', 'confirmed', 'changed', 'cancelled', 'completed']
const reservationStatuses = ['requested', 'confirmed', 'changed', 'cancelled', 'completed']
const orderStatuses = ['placed', 'confirmed', 'preparing', 'ready', 'delivered', 'cancelled']

export default {
  fetch: withSupabase({ auth: 'none' }, async (req, ctx) => {
    if (req.method === 'OPTIONS') {
      return new Response('ok', { headers: corsHeaders })
    }

    try {
      const body = await req.json()
      const initData = String(body.initData ?? '')
      const botToken = Deno.env.get('FINETIME_TELEGRAM_BOT_TOKEN')
      if (!botToken) {
        return response({ error: 'Partner service is not configured.' }, 503)
      }

      const tgUser = await validateTelegramInitData(initData, botToken)
      const telegramUserId = String(tgUser.id)
      const admin = ctx.supabaseAdmin

      if (body.action === 'activate') {
        const code = String(body.code ?? '').trim().toUpperCase()
        if (!/^[A-Z0-9-]{6,64}$/.test(code)) {
          return response({ error: 'Enter a valid activation code.' }, 400)
        }

        const existing = await membership(admin, telegramUserId)
        if (existing.length) {
          return response({
            error: 'This Telegram account is already connected to a FineTime business. Contact FineTime Admin if it needs to be changed.',
            code: 'ALREADY_CONNECTED',
          }, 409)
        }

        const digest = await crypto.subtle.digest(
          'SHA-256',
          new TextEncoder().encode(code),
        )
        const codeHash = hex(digest)

        const { data: activation, error: activationError } = await admin
          .from('activation_codes')
          .select('id,business_id,expires_at,used_at,revoked_at')
          .eq('code_hash', codeHash)
          .maybeSingle()

        if (activationError) throw activationError
        if (
          !activation ||
          activation.used_at ||
          activation.revoked_at ||
          (activation.expires_at && new Date(activation.expires_at) < new Date())
        ) {
          return response({
            error: 'This activation code is invalid, expired, used, or revoked.',
          }, 403)
        }

        const { data: claimed, error: claimError } = await admin
          .from('activation_codes')
          .update({ used_at: new Date().toISOString() })
          .eq('id', activation.id)
          .is('used_at', null)
          .is('revoked_at', null)
          .select('id')
          .maybeSingle()

        if (claimError) throw claimError
        if (!claimed) {
          return response({
            error: 'This activation code has already been used or revoked.',
          }, 403)
        }

        const { error: connectionError } = await admin
          .from('telegram_connections')
          .upsert({
            business_id: activation.business_id,
            telegram_user_id: telegramUserId,
            revoked_at: null,
          }, { onConflict: 'business_id,telegram_user_id' })

        if (connectionError) throw connectionError

        const { error: memberError } = await admin
          .from('partner_business_members')
          .upsert({
            business_id: activation.business_id,
            telegram_user_id: telegramUserId,
            role: 'partner',
          }, { onConflict: 'business_id,telegram_user_id' })

        if (memberError) throw memberError

        return response({ ok: true, business_id: activation.business_id })
      }

      const memberships = await membership(admin, telegramUserId)
      if (!memberships.length) {
        return response({
          error: 'Your business account is not connected. Please contact FineTime Admin and request an activation code.',
          code: 'UNCONNECTED',
        }, 403)
      }

      const selected = memberships[0]
      const businessId = selected.business_id

      if (body.action === 'bootstrap') {
        const [{ data: business }, { data: bookings }, { data: reservations }, { data: orders }, { data: rooms }, { data: categories }, { data: promotions }, { data: subscription }] =
          await Promise.all([
            admin.from('businesses').select('*').eq('id', businessId).single(),
            admin.from('bookings').select('*, profiles(full_name,phone), room_types(name)').eq('business_id', businessId).order('created_at', { ascending: false }).limit(50),
            admin.from('reservations').select('*, profiles(full_name,phone)').eq('business_id', businessId).order('created_at', { ascending: false }).limit(50),
            admin.from('orders').select('*').eq('business_id', businessId).order('created_at', { ascending: false }).limit(50),
            admin.from('room_types').select('*').eq('business_id', businessId).order('name'),
            admin.from('menu_categories').select('*, menu_items(*)').eq('business_id', businessId).order('sort_order'),
            admin.from('promotions').select('*').eq('business_id', businessId).order('starts_on', { ascending: false }),
            admin.from('business_subscriptions').select('*').eq('business_id', businessId).maybeSingle(),
          ])

        const roomIds = (rooms ?? []).map((x: any) => x.id)
        const { data: inventory, error: inventoryError } = roomIds.length
          ? await admin
              .from('room_inventory')
              .select('*')
              .in('room_type_id', roomIds)
              .gte('inventory_date', new Date().toISOString().slice(0, 10))
              .lte('inventory_date', new Date(Date.now() + 1000 * 60 * 60 * 24 * 90).toISOString().slice(0, 10))
              .order('inventory_date')
          : { data: [], error: null }

        if (inventoryError) throw inventoryError

        return response({
          business,
          bookings: bookings ?? [],
          reservations: reservations ?? [],
          orders: orders ?? [],
          rooms: rooms ?? [],
          inventory: inventory ?? [],
          categories: categories ?? [],
          promotions: promotions ?? [],
          subscription: subscription ?? null,
        })
      }

      if (body.action === 'update_inventory') {
        const roomTypeId = String(body.room_type_id ?? '')
        const inventoryDate = String(body.inventory_date ?? '')
        const availableRooms = Number(body.available_rooms)
        const blocked = Boolean(body.blocked)

        if (!roomTypeId || !/^\d{4}-\d{2}-\d{2}$/.test(inventoryDate) ||
            !Number.isInteger(availableRooms) || availableRooms < 0) {
          return response({ error: 'Invalid room inventory values.' }, 400)
        }

        const { data: room, error: roomError } = await admin
          .from('room_types')
          .select('id,total_rooms')
          .eq('id', roomTypeId)
          .eq('business_id', businessId)
          .maybeSingle()

        if (roomError) throw roomError
        if (!room) return response({ error: 'Room type not found for this business.' }, 404)
        const totalRooms = Number(room.total_rooms ?? 0)
        if (availableRooms > totalRooms) {
          return response({ error: 'Available rooms cannot exceed total rooms.' }, 400)
        }

        const { data: heldBookings, error: heldError } = await admin
          .from('bookings')
          .select('id')
          .eq('business_id', businessId)
          .eq('room_type_id', roomTypeId)
          .in('status', ['requested', 'confirmed', 'changed'])
          .lt('check_in', inventoryDate)
          .gt('check_out', inventoryDate)

        if (heldError) throw heldError

        const maxAvailable = Math.max(0, totalRooms - (heldBookings ?? []).length)
        if (availableRooms > maxAvailable) {
          return response({ error: 'Inventory edit would exceed the rooms not already held by bookings.' }, 409)
        }

        const { data, error } = await admin
          .from('room_inventory')
          .upsert({
            room_type_id: roomTypeId,
            inventory_date: inventoryDate,
            available_rooms: availableRooms,
            blocked,
            updated_at: new Date().toISOString(),
          }, { onConflict: 'room_type_id,inventory_date' })
          .select()
          .single()

        if (error) throw error
        return response({ ok: true, data })
      }

      const asArray = (value: unknown) =>
        Array.isArray(value) ? value.map((x) => String(x).trim()).filter(Boolean) : []

      if (body.action === 'update_business') {
        const patch: Record<string, unknown> = {}
        if (body.name !== undefined) patch.name = String(body.name).trim()
        if (body.about !== undefined) patch.about = String(body.about).trim()
        if (body.phone !== undefined) patch.phone = String(body.phone).trim()
        if (body.cover_url !== undefined) patch.cover_url = String(body.cover_url).trim()
        if (body.gallery_urls !== undefined) patch.gallery_urls = asArray(body.gallery_urls)
        if (body.highlights !== undefined) patch.highlights = asArray(body.highlights)
        if (body.amenities !== undefined) patch.amenities = asArray(body.amenities)
        if (body.services !== undefined) patch.services = asArray(body.services)
        if (body.opening_hours !== undefined) patch.opening_hours = body.opening_hours
        if (body.lat !== undefined) patch.lat = Number(body.lat)
        if (body.lng !== undefined) patch.lng = Number(body.lng)
        if (!Object.keys(patch).length) return response({ error: 'No business changes supplied.' }, 400)

        const { data, error } = await admin.from('businesses')
          .update(patch).eq('id', businessId).select('*').single()
        if (error) throw error
        return response({ ok: true, business: data })
      }

      if (body.action === 'upsert_category') {
        const id = body.id ? String(body.id) : null
        const name = String(body.name ?? '').trim()
        const sortOrder = Number.isInteger(body.sort_order) ? body.sort_order : 0
        if (!name || name.length > 120) return response({ error: 'Category name is required.' }, 400)

        const query = id
          ? admin.from('menu_categories').update({ name, sort_order: sortOrder }).eq('id', id).eq('business_id', businessId).select().single()
          : admin.from('menu_categories').insert({ business_id: businessId, name, sort_order: sortOrder }).select().single()
        const { data, error } = await query
        if (error) throw error
        return response({ ok: true, category: data })
      }

      if (body.action === 'delete_category') {
        const id = String(body.id ?? '')
        if (!id) return response({ error: 'Category id is required.' }, 400)
        const { data: items, error: itemError } = await admin.from('menu_items').select('id').eq('category_id', id)
        if (itemError) throw itemError
        if ((items ?? []).length) return response({ error: 'Remove or move the menu items in this category first.' }, 409)
        const { error } = await admin.from('menu_categories').delete().eq('id', id).eq('business_id', businessId)
        if (error) throw error
        return response({ ok: true })
      }

      if (body.action === 'upsert_menu_item') {
        const id = body.id ? String(body.id) : null
        const categoryId = String(body.category_id ?? '')
        const name = String(body.name ?? '').trim()
        const description = body.description == null ? null : String(body.description).trim()
        const price = body.price == null || body.price === '' ? null : Number(body.price)
        const photoUrl = body.photo_url == null ? null : String(body.photo_url).trim()
        const available = body.is_available === undefined ? true : Boolean(body.is_available)
        if (!categoryId || !name || name.length > 160 || (price !== null && (!Number.isFinite(price) || price < 0))) {
          return response({ error: 'Invalid menu item values.' }, 400)
        }

        const { data: category, error: categoryError } = await admin.from('menu_categories')
          .select('id').eq('id', categoryId).eq('business_id', businessId).maybeSingle()
        if (categoryError) throw categoryError
        if (!category) return response({ error: 'Category not found for this business.' }, 404)

        const payload = { category_id: categoryId, name, description, price, photo_url: photoUrl, is_available: available }
        const query = id
          ? admin.from('menu_items').update(payload).eq('id', id).eq('category_id', categoryId).select().single()
          : admin.from('menu_items').insert(payload).select().single()
        const { data, error } = await query
        if (error) throw error
        return response({ ok: true, item: data })
      }

      if (body.action === 'delete_menu_item') {
        const id = String(body.id ?? '')
        if (!id) return response({ error: 'Menu item id is required.' }, 400)
        const { data: item, error: itemError } = await admin.from('menu_items').select('id,category_id').eq('id', id).maybeSingle()
        if (itemError) throw itemError
        if (!item) return response({ error: 'Menu item not found.' }, 404)
        const { data: category, error: categoryError } = await admin.from('menu_categories').select('id').eq('id', item.category_id).eq('business_id', businessId).maybeSingle()
        if (categoryError) throw categoryError
        if (!category) return response({ error: 'Menu item is not owned by this business.' }, 403)
        const { error } = await admin.from('menu_items').delete().eq('id', id)
        if (error) throw error
        return response({ ok: true })
      }

      if (body.action === 'upsert_room') {
        const id = body.id ? String(body.id) : null
        const name = String(body.name ?? '').trim()
        const totalRooms = Number(body.total_rooms)
        const capacity = Number(body.capacity)
        const publicPrice = body.public_price == null || body.public_price === '' ? null : Number(body.public_price)
        if (!name || !Number.isInteger(totalRooms) || totalRooms < 0 ||
            !Number.isInteger(capacity) || capacity < 1 ||
            (publicPrice !== null && (!Number.isFinite(publicPrice) || publicPrice < 0))) {
          return response({ error: 'Invalid room values.' }, 400)
        }
        const payload = {
          name,
          description: body.description == null ? null : String(body.description).trim(),
          capacity,
          beds: body.beds == null ? null : String(body.beds).trim(),
          amenities: asArray(body.amenities),
          photo_url: body.photo_url == null ? null : String(body.photo_url).trim(),
          public_price: publicPrice,
          total_rooms: totalRooms,
        }
        const query = id
          ? admin.from('room_types').update(payload).eq('id', id).eq('business_id', businessId).select().single()
          : admin.from('room_types').insert({ ...payload, business_id: businessId }).select().single()
        const { data, error } = await query
        if (error) throw error
        return response({ ok: true, room: data })
      }

      if (body.action === 'delete_room') {
        const id = String(body.id ?? '')
        if (!id) return response({ error: 'Room id is required.' }, 400)
        const { error } = await admin.from('room_types').delete().eq('id', id).eq('business_id', businessId)
        if (error) throw error
        return response({ ok: true })
      }

      if (body.action === 'upsert_promotion') {
        const id = body.id ? String(body.id) : null
        const title = String(body.title ?? '').trim()
        if (!title) return response({ error: 'Promotion title is required.' }, 400)
        const badge = body.badge == null ? null : String(body.badge)
        const allowedBadges = ['25% OFF','TODAY','NEW','FEATURED','LIMITED','FINE TIME PICK']
        if (badge && !allowedBadges.includes(badge)) return response({ error: 'Invalid promotion badge.' }, 400)
        const payload = {
          title,
          description: body.description == null ? null : String(body.description).trim(),
          badge,
          image_url: body.image_url == null ? null : String(body.image_url).trim(),
          terms: body.terms == null ? null : String(body.terms).trim(),
          starts_on: body.starts_on || null,
          ends_on: body.ends_on || null,
          status: body.status === 'inactive' ? 'inactive' : 'active',
        }
        const query = id
          ? admin.from('promotions').update(payload).eq('id', id).eq('business_id', businessId).select().single()
          : admin.from('promotions').insert({ ...payload, business_id: businessId }).select().single()
        const { data, error } = await query
        if (error) throw error
        return response({ ok: true, promotion: data })
      }

      if (body.action === 'delete_promotion') {
        const id = String(body.id ?? '')
        const { error } = await admin.from('promotions').delete().eq('id', id).eq('business_id', businessId)
        if (error) throw error
        return response({ ok: true })
      }

      if (body.action === 'update_subscription') {
        const plan = String(body.plan ?? '')
        const status = String(body.status ?? '')
        if (!['basic','premium'].includes(plan) || !['active','paused','expired','cancelled'].includes(status)) {
          return response({ error: 'Invalid subscription values.' }, 400)
        }
        const payload = {
          business_id: businessId,
          plan,
          status,
          monthly_price: body.monthly_price == null || body.monthly_price === '' ? null : Number(body.monthly_price),
          starts_on: body.starts_on || null,
          ends_on: body.ends_on || null,
          notes: body.notes == null ? null : String(body.notes).trim(),
          updated_at: new Date().toISOString(),
        }
        const { data, error } = await admin.from('business_subscriptions')
          .upsert(payload, { onConflict: 'business_id' }).select().single()
        if (error) throw error
        return response({ ok: true, subscription: data })
      }

      const tableByAction: Record<string, string> = {
        update_booking: 'bookings',
        update_reservation: 'reservations',
        update_order: 'orders',
      }

      const table = tableByAction[body.action]
      if (table) {
        const id = String(body.id ?? '')
        const status = String(body.status ?? '')
        const allowed = table === 'bookings'
          ? bookingStatuses
          : table === 'reservations'
            ? reservationStatuses
            : orderStatuses

        if (!id || !allowed.includes(status)) {
          return response({ error: 'Invalid status update.' }, 400)
        }

        const { data, error } = await admin
          .from(table)
          .update({ status })
          .eq('id', id)
          .eq('business_id', businessId)
          .select()
          .single()

        if (error) {
          if (error.code === 'P0001') {
            return response({ error: error.message }, 409)
          }
          throw error
        }

        if (table === 'bookings' || table === 'reservations') {
          const targetUserId = data.user_id
          if (targetUserId) {
            const label = table === 'bookings' ? 'hotel booking' : 'table reservation'
            await admin.from('notifications').insert({
              user_id: targetUserId,
              title: status === 'confirmed' ? 'Booking confirmed' : status === 'cancelled' ? 'Booking cancelled' : 'Booking updated',
              body: `Your ${label} at FineTime is now ${status}.`,
              type: table === 'bookings' ? 'booking' : 'reservation',
              reference_type: table === 'bookings' ? 'booking' : 'reservation',
              reference_id: data.id,
            })
          }
        }

        return response({ ok: true, data })
      }

      return response({ error: 'Unknown partner action.' }, 400)
    } catch (error) {
      console.error(error)
      return response({
        error: error instanceof Error ? error.message : 'Partner request failed.',
      }, 500)
    }
  }),
}
