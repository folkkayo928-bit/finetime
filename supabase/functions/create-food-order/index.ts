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
