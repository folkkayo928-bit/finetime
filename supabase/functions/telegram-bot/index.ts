import { withSupabase } from 'npm:@supabase/server'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'content-type',
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

async function telegram(token: string, method: string, payload: Record<string, unknown>) {
  const res = await fetch(`https://api.telegram.org/bot${token}/${method}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  })
  const data = await res.json()
  if (!res.ok || !data.ok) throw new Error(data.description || 'Telegram API request failed.')
  return data
}

export default {
  fetch: withSupabase({ auth: 'none' }, async (req, ctx) => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
    if (req.method !== 'POST') return json({ error: 'POST required.' }, 405)

    const token = Deno.env.get('FINETIME_TELEGRAM_BOT_TOKEN')
    if (!token) return json({ error: 'Telegram bot is not configured.' }, 503)

    try {
      const update = await req.json()
      const message = update?.message
      if (!message?.chat?.id) return json({ ok: true })

      const chatId = String(message.chat.id)
      const telegramUserId = String(message.from?.id ?? '')
      const text = String(message.text ?? '').trim()
      const admin = ctx.supabaseAdmin

      if (telegramUserId) {
        const { data: membership } = await admin
          .from('partner_business_members')
          .select('business_id')
          .eq('telegram_user_id', telegramUserId)
          .limit(1)
          .maybeSingle()

        if (membership?.business_id) {
          await admin.from('telegram_connections')
            .update({ telegram_chat_id: chatId, revoked_at: null })
            .eq('business_id', membership.business_id)
            .eq('telegram_user_id', telegramUserId)
        }
      }

      if (text === '/start' || text === '/partner' || text === '/menu') {
        const miniAppUrl = 'https://folkkayo928-bit.github.io/finetime/partner.html?v=20260930d'
        await telegram(token, 'sendMessage', {
          chat_id: chatId,
          text: 'FineTime Partner\n\nOpen your business workspace to manage your profile, menu, rooms, availability, reservations, bookings and promotions.',
          reply_markup: {
            inline_keyboard: [[{ text: 'Open FineTime Partner', web_app: { url: miniAppUrl } }]],
          },
        })
        return json({ ok: true })
      }

      await telegram(token, 'sendMessage', {
        chat_id: chatId,
        text: 'Use the FineTime Partner button below to open your business workspace.',
        reply_markup: {
          inline_keyboard: [[{ text: 'Open FineTime Partner', web_app: { url: 'https://folkkayo928-bit.github.io/finetime/partner.html?v=20260930d' } }]],
        },
      })
      return json({ ok: true })
    } catch (error) {
      console.error(error)
      return json({ error: error instanceof Error ? error.message : 'Telegram webhook failed.' }, 500)
    }
  }),
}
