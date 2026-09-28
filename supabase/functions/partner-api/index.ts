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
        const [{ data: business }, { data: bookings }, { data: reservations }, { data: orders }, { data: rooms }, { data: inventory }] =
          await Promise.all([
            admin.from('businesses').select('*').eq('id', businessId).single(),
            admin.from('bookings').select('*, profiles(full_name,phone), room_types(name)').eq('business_id', businessId).order('created_at', { ascending: false }).limit(50),
            admin.from('reservations').select('*, profiles(full_name,phone)').eq('business_id', businessId).order('created_at', { ascending: false }).limit(50),
            admin.from('orders').select('*').eq('business_id', businessId).order('created_at', { ascending: false }).limit(50),
            admin.from('room_types').select('*').eq('business_id', businessId).order('name'),
            admin.from('room_inventory').select('*').in('room_type_id',
              (await admin.from('room_types').select('id').eq('business_id', businessId)).data?.map((x: any) => x.id) ?? []
            ).gte('inventory_date', new Date().toISOString().slice(0, 10)).lte(
              new Date(Date.now() + 1000 * 60 * 60 * 24 * 90).toISOString().slice(0, 10)
            ).order('inventory_date'),
          ])

        return response({
          business,
          bookings: bookings ?? [],
          reservations: reservations ?? [],
          orders: orders ?? [],
          rooms: rooms ?? [],
          inventory: inventory ?? [],
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
        if (availableRooms > Number(room.total_rooms ?? 0)) {
          return response({ error: 'Available rooms cannot exceed total rooms.' }, 400)
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
