import { withSupabase } from 'npm:@supabase/server'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

export default {
  fetch: withSupabase({ auth: 'user' }, async (req, ctx) => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
    try {
      const body = await req.json()
      const businessId = String(body.business_id ?? '')
      const items = body.items
      if (!businessId || !Array.isArray(items) || items.length === 0) {
        return Response.json({ error: 'Invalid order request.' }, { status: 400, headers: corsHeaders })
      }

      const userId = ctx.userClaims?.sub
      if (!userId) return Response.json({ error: 'Authentication required.' }, { status: 401, headers: corsHeaders })

      const { data, error } = await ctx.supabaseAdmin.rpc('create_food_order_internal', {
        p_user_id: userId,
        p_business_id: businessId,
        p_items: items,
        p_table_number: body.table_number ?? null,
        p_customer_note: body.customer_note ?? null,
      })
      if (error) throw error
      return Response.json(data, { headers: corsHeaders })
    } catch (error) {
      console.error(error)
      return Response.json(
        { error: error instanceof Error ? error.message : 'Could not create order.' },
        { status: 400, headers: corsHeaders },
      )
    }
  }),
}
