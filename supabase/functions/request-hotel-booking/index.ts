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
      const roomTypeId = String(body.room_type_id ?? '')
      const checkIn = String(body.check_in ?? '')
      const checkOut = String(body.check_out ?? '')
      const guests = Number(body.guests)

      if (!businessId || !roomTypeId || !/^\d{4}-\d{2}-\d{2}$/.test(checkIn) ||
          !/^\d{4}-\d{2}-\d{2}$/.test(checkOut) || !Number.isInteger(guests)) {
        return Response.json({ error: 'Invalid booking request.' }, { status: 400, headers: corsHeaders })
      }

      const { data, error } = await admin.rpc('request_hotel_booking_internal', {
        p_user_id: user.id,
        p_business_id: businessId,
        p_room_type_id: roomTypeId,
        p_check_in: checkIn,
        p_check_out: checkOut,
        p_guests: guests,
      })
      if (error) throw error
      return Response.json(data, { headers: corsHeaders })
    } catch (error) {
      console.error(error)
      return Response.json(
        { error: error instanceof Error ? error.message : 'Could not request booking.' },
        { status: 400, headers: corsHeaders },
      )
    }
  },
}
