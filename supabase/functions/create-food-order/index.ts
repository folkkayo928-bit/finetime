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
    if (!connection.telegram_chat_id) continue
    try {
      await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          chat_id: connection.telegram_chat_id,
          text,
          disable_notification: false,
          reply_markup: { inline_keyboard: [[{ text: 'Open FineTime Partner', web_app: { url: 'https://folkkayo928-bit.github.io/finetime/partner/' } }]] },
        }),
      })
    } catch (error) { console.error('Partner Telegram notification failed', error) }
  }
}

export default {
  fetch: async (req: Request) => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
    try {
      const { supabase, admin } = clients(req)
      const authorization = req.headers.get('Authorization') ?? ''
      const token = authorization.startsWith('Bearer ') ? authorization.slice(7).trim() : ''
      if (!token) {
        return Response.json({ error: 'Authentication required.' }, { status: 401, headers: corsHeaders })
      }

      const { data: { user }, error: authError } = await supabase.auth.getUser(token)
      if (authError || !user) {
        return Response.json({ error: 'Authentication required.' }, { status: 401, headers: corsHeaders })
      }

      const body = await req.json()
      const businessId = String(body.business_id ?? '')
      const items = body.items
      if (!businessId || !Array.isArray(items) || items.length === 0) {
        return Response.json({ error: 'Invalid order request.' }, { status: 400, headers: corsHeaders })
      }

      const { data, error } = await admin.rpc('create_food_order_internal', {
        p_user_id: user.id,
        p_business_id: businessId,
        p_items: items,
        p_table_number: body.table_number ?? null,
        p_customer_note: body.customer_note ?? null,
      })
      if (error) throw error
      const { data: profile } = await admin.from('profiles').select('full_name').eq('id', user.id).maybeSingle()
      await notifyPartner(
        admin,
        businessId,
        `🔔 New food order\\n\\n${profile?.full_name || 'FineTime customer'}${body.table_number ? ` · Table ${body.table_number}` : ''}\\nTotal: ETB ${data?.total ?? '—'}\\n\\nOpen FineTime Partner to Accept or Reject.`,
      )
      return Response.json(data, { headers: corsHeaders })
    } catch (error) {
      console.error(error)
      return Response.json(
        { error: error instanceof Error ? error.message : 'Could not create order.' },
        { status: 400, headers: corsHeaders },
      )
    }
  },
}
