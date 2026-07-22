import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import nodemailer from "npm:nodemailer"

// [H-05 FIX] Restrict CORS to known origins
const ALLOWED_ORIGINS = [
  "https://studysphere.app",
  "https://studysphere-app-3a480.web.app",
  "https://studysphere-app-3a480.firebaseapp.com",
  "http://localhost",
  "http://localhost:3000",
]

function getCorsHeaders(origin: string | null): Record<string, string> {
  const allowedOrigin = origin && ALLOWED_ORIGINS.includes(origin)
    ? origin
    : ALLOWED_ORIGINS[0]
  return {
    'Access-Control-Allow-Origin': allowedOrigin,
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-firebase-token',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  }
}

serve(async (req) => {
  const origin = req.headers.get('origin')
  const corsHeaders = getCorsHeaders(origin)

  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // [H-04 FIX] Verify Firebase token before allowing email to be sent.
    // This prevents open email relay abuse.
    const token = req.headers.get('x-firebase-token')
    if (!token) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const firebaseApiKey = Deno.env.get('FIREBASE_API_KEY')
    if (!firebaseApiKey) {
      console.error('FIREBASE_API_KEY not configured')
      return new Response(
        JSON.stringify({ error: 'Service unavailable' }),
        { status: 503, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const verifyRes = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${firebaseApiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ idToken: token }),
      }
    )
    const verifyData = await verifyRes.json()
    if (!verifyRes.ok || !verifyData.users?.[0]?.localId) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { email, name } = await req.json()
    if (!email || typeof email !== 'string' || !email.includes('@') || email.length > 254) {
      return new Response(
        JSON.stringify({ error: 'Invalid email address' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const smtpEmail = Deno.env.get("SMTP_EMAIL")
    const smtpPassword = Deno.env.get("SMTP_PASSWORD")

    if (!smtpEmail || !smtpPassword) {
      throw new Error("SMTP credentials not configured")
    }

    // Create transporter
    const transporter = nodemailer.createTransport({
      service: "gmail",
      auth: {
        user: smtpEmail,
        pass: smtpPassword,
      },
    })

    // HTML Template
    let htmlContent = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome to StudySphere!</title>
    <style>
        /* CSS reset & base */
        body { margin: 0; padding: 0; background-color: #0f172a; font-family: 'Inter', 'Segoe UI', Roboto, sans-serif; -webkit-font-smoothing: antialiased; }
        .wrapper { width: 100%; table-layout: fixed; background-color: #0f172a; padding: 40px 0; }
        
        /* Container */
        .main { 
            background: linear-gradient(180deg, #1e293b 0%, #0f172a 100%); 
            margin: 0 auto; 
            width: 100%; 
            max-width: 600px; 
            border-radius: 24px; 
            box-shadow: 0 20px 40px rgba(0,0,0,0.4), inset 0 1px 0 rgba(255,255,255,0.1); 
            overflow: hidden; 
            border: 1px solid #334155;
        }
        
        /* Header */
        .header { 
            background: url('https://images.unsplash.com/photo-1557683316-973673baf926?q=80&w=600&auto=format&fit=crop') center/cover;
            padding: 60px 30px; 
            text-align: center; 
            position: relative;
        }
        .header::before {
            content: '';
            position: absolute;
            top: 0; left: 0; right: 0; bottom: 0;
            background: rgba(15, 23, 42, 0.7);
        }
        .header-content { position: relative; z-index: 2; }
        .logo-circle {
            background: linear-gradient(135deg, #00f2fe 0%, #4facfe 100%);
            width: 80px; height: 80px;
            border-radius: 50%;
            display: inline-block;
            line-height: 80px;
            margin-bottom: 20px;
            box-shadow: 0 0 20px rgba(79, 172, 254, 0.5);
            text-align: center;
        }
        .logo-circle img { width: 40px; height: 40px; filter: brightness(0) invert(1); vertical-align: middle; }
        .header h1 { 
            color: #ffffff; 
            margin: 0; 
            font-size: 32px; 
            font-weight: 800; 
            letter-spacing: -1px; 
            text-shadow: 0 2px 10px rgba(0,0,0,0.5);
        }
        .header p { color: #e2e8f0; font-size: 16px; margin-top: 10px; font-weight: 500; }

        /* Content */
        .content { padding: 40px; text-align: center; }
        .content h2 { color: #f8fafc; font-size: 24px; margin-bottom: 15px; }
        .content p.lead { font-size: 16px; line-height: 1.6; color: #cbd5e1; margin-bottom: 30px; }
        
        /* Features */
        .feature-grid { text-align: left; margin: 30px 0; }
        .feature-item { 
            background: rgba(30, 41, 59, 0.5); 
            border: 1px solid #334155;
            padding: 20px; 
            border-radius: 16px; 
            margin-bottom: 15px;
            position: relative;
            overflow: hidden;
        }
        .feature-item::before {
            content: ''; position: absolute; left: 0; top: 0; bottom: 0; width: 4px;
            background: linear-gradient(180deg, #00f2fe 0%, #4facfe 100%);
        }
        .feature-icon { font-size: 24px; margin-bottom: 10px; display: inline-block; }
        .feature-item h3 { margin: 0 0 8px 0; color: #f1f5f9; font-size: 18px; font-weight: 600; }
        .feature-item p { margin: 0; font-size: 14px; color: #94a3b8; line-height: 1.5; }

        /* CTA */
        .cta-container { margin-top: 40px; margin-bottom: 20px; }
        .button { 
            display: inline-block; 
            background: linear-gradient(135deg, #00f2fe 0%, #4facfe 100%); 
            color: #ffffff !important; 
            text-decoration: none; 
            padding: 16px 40px; 
            border-radius: 50px; 
            font-weight: 700; 
            font-size: 16px; 
            letter-spacing: 0.5px;
            box-shadow: 0 10px 20px -5px rgba(79, 172, 254, 0.5); 
        }
        
        /* Footer */
        .footer { padding: 30px; text-align: center; background-color: #0f172a; border-top: 1px solid #1e293b; }
        .footer p { margin: 0; font-size: 13px; color: #64748b; line-height: 1.5; }
    </style>
</head>
<body>
    <center class="wrapper">
        <table class="main" width="100%" cellpadding="0" cellspacing="0">
            <tr>
                <td class="header">
                    <div class="header-content">
                        <div class="logo-circle">
                            <img src="https://cdn-icons-png.flaticon.com/512/3003/3003511.png" alt="Logo">
                        </div>
                        <h1>Welcome to StudySphere!</h1>
                        <p>Your Ultimate Learning Companion 🚀</p>
                    </div>
                </td>
            </tr>
            <tr>
                <td class="content">
                    <h2>Hello there! 👋</h2>
                    <p class="lead">We're absolutely thrilled to have you on board. StudySphere is designed to revolutionize the way you learn, making it smarter, faster, and much more engaging.</p>
                    
                    <div class="feature-grid">
                        <div class="feature-item">
                            <span class="feature-icon">🤖</span>
                            <h3>AI-Powered Assistance</h3>
                            <p>Stuck on a topic? Ask our AI for instant explanations, summaries, and customized MCQs to test your knowledge.</p>
                        </div>
                        <div class="feature-item">
                            <span class="feature-icon">📚</span>
                            <h3>Vast Digital Library</h3>
                            <p>Access thousands of curated notes, study materials, and college documents in just one tap.</p>
                        </div>
                        <div class="feature-item">
                            <span class="feature-icon">🎯</span>
                            <h3>Exam Ready</h3>
                            <p>Practice with real past question papers, track your progress, and confidently ace your upcoming exams.</p>
                        </div>
                    </div>

                    <div class="cta-container">
                        <a href="https://studysphere.app" class="button">Start Learning Now</a>
                    </div>
                </td>
            </tr>
            <tr>
                <td class="footer">
                    <p>You received this email because you registered on StudySphere.</p>
                    <p>Sent to <strong>%EMAIL%</strong></p>
                    <p style="margin-top: 15px;">&copy; 2026 StudySphere. All rights reserved.</p>
                </td>
            </tr>
        </table>
    </center>
</body>
</html>`

    htmlContent = htmlContent.replace(/%EMAIL%/g, email)

    const mailOptions = {
      from: `"StudySphere" <${smtpEmail}>`,
      to: email,
      subject: "Welcome to StudySphere! 🎉",
      html: htmlContent,
    }

    const info = await transporter.sendMail(mailOptions)

    return new Response(
      JSON.stringify({ success: true, messageId: info.messageId }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 },
    )
  } catch (error) {
    // [H-07 FIX] Don't expose raw error details
    console.error('Error in send-welcome-email:', error)
    return new Response(
      JSON.stringify({ error: 'Failed to send email. Please try again.' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 },
    )
  }
})
