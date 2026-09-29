import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

function clients(req: Request) {
  const url = Deno.env.get('SUPABASE_URL') ?? ''
  const anon = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
  const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  const authorization = req.headers.get('Authorization') ?? ''
  const supabase = createClient(url, anon, {
    global: { headers: { Authorization: authorization } },
  })
  const admin = createClient(url, service)
  return { supabase, admin }
}

async function notifyPartner(admin: ReturnType<typeof createClient>, businessId: string, text: string) {
  const token = Deno.env.get('FINETIME_TELEGRAM_BOT_TOKEN')
  if (!token) return
  const { data: connections } = await admin
    .from('telegram_connections')
    .select('telegram_chat_id')
    .eq('business_id', businessId)
    .not('telegram_chat_id', 'is', null)

  for (const connection of connections ?? []) {
    const chatId = connection.telegram_chat_id
    if (!chatId) continue
    try {
      await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          chat_id: chatId,
          text,
          disable_notification: false,
          reply_markup: {
            inline_keyboard: [[{
              text: 'Open FineTime Partner',
              web_app: { url: 'https://folkkayo928-bit.github.io/finetime/partner/' },
            }]],
          },
        }),
      })
    } catch (error) {
      console.error('Partner Telegram notification failed', error)
    }
  }
}

export default {
  fetch: async (req: Request) => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
    try {
      const { supabase, admin } = clients(req)
      const authorization = req.headers.get('Authorization') ?? ''
      const token = authorization.startsWith('Bearer ') ? authorization.slice(7).trim() : ''
      if (!token) return Response.json({ error: 'Authentication required.' }, { status: 401, headers: corsHeaders })

      const { data: { user }, error: authError } = await supabase.auth.getUser(token)
      if (authError || !user) return Response.json({ error: 'Authentication required.' }, { status: 401, headers: corsHeaders })

      const body = await req.json()
      const businessId = String(body.business_id ?? '')
      const reservationDate = String(body.reservation_date ?? '')
      const reservationTime = String(body.reservation_time ?? '')
      const partySize = Number(body.party_size)
      const contactPhone = String(body.contact_phone ?? '').trim()
      const specialRequest = body.special_request == null ? null : String(body.special_request).trim() || null

      if (!businessId || !/^\d{4}-\d{2}-\d{2}$/.test(reservationDate) ||
          !/^\d{2}:\d{2}:\d{2}$/.test(reservationTime) ||
          !Number.isInteger(partySize) || partySize < 1 || partySize > 50 || !contactPhone) {
        return Response.json({ error: 'Invalid reservation request.' }, { status: 400, headers: corsHeaders })
      }

      const { data: business, error: businessError } = await admin
        .from('businesses')
        .select('id,name')
        .eq('id', businessId)
        .maybeSingle()
      if (businessError) throw businessError
      if (!business) return Response.json({ error: 'Business not found.' }, { status: 404, headers: corsHeaders })

      const { data, error } = await admin
        .from('reservations')
        .insert({
          user_id: user.id,
          business_id: businessId,
          reservation_date: reservationDate,
          reservation_time: reservationTime,
          party_size: partySize,
          contact_phone: contactPhone,
          special_request: specialRequest,
        })
        .select('id,status,reservation_date,reservation_time,party_size')
        .single()
      if (error) throw error

      const { data: profile } = await admin.from('profiles').select('full_name').eq('id', user.id).maybeSingle()
      const customerName = profile?.full_name || 'FineTime customer'
      await notifyPartner(
        admin,
        businessId,
        `🔔 New table reservation request\n\n${customerName}\n${reservationDate} at ${reservationTime.slice(0,5)} · ${partySize} guest(s)\n${contactPhone}\n\nOpen FineTime Partner to Accept or Reject.`,
      )

      return Response.json(data, { headers: corsHeaders })
    } catch (error) {
      console.error(error)
      return Response.json(
        { error: error instanceof Error ? error.message : 'Could not submit reservation.' },
        { status: 400, headers: corsHeaders },
      )
    }
  },
}
