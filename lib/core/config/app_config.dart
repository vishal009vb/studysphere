// ── App Configuration ─────────────────────────────────────────────────────────
//
// Security Note:
// • SUPABASE_URL and SUPABASE_ANON_KEY are intentionally semi-public.
//   Supabase's security model is Row-Level Security (RLS), not key secrecy.
//   These values are safe in compiled code.
// • The GEMINI_API_KEY is NEVER stored here. It lives in Supabase Secrets only
//   and is accessed exclusively by the gemini-chat Edge Function server-side.
// • Firebase API keys are also intentionally public (restricted by App Check +
//   Firebase Security Rules).
// ─────────────────────────────────────────────────────────────────────────────

class AppConfig {
  AppConfig._(); // Static-only class

  // ── Supabase ──────────────────────────────────────────────────────────────
  // Anon key is the publishable key — safe to be in the client bundle.
  // Server-side Edge Functions use service_role secrets for privileged ops.
  static const String supabaseUrl = 'https://sngynecejyxlamfkrsjs.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_vcKRMPSQOvZeZtNZSwUbCA_jSwv9QdY';

  // ── Edge Function URLs ────────────────────────────────────────────────────
  static const String scanPdfUrl =
      '$supabaseUrl/functions/v1/scan-pdf';
  static const String geminiChatUrl =
      '$supabaseUrl/functions/v1/gemini-chat';
  static const String sendWelcomeEmailUrl =
      '$supabaseUrl/functions/v1/send-welcome-email';

  // ── Upload Constraints ────────────────────────────────────────────────────
  static const int maxUploadSizeBytes = 20 * 1024 * 1024; // 20 MB
  static const List<String> allowedUploadExtensions = ['.pdf'];

  // ── Server-Side Rate Limits (hard limits enforced by Edge Functions) ──────
  // Displayed in UI so users understand constraints.
  static const int uploadMaxPerHour = 5;
  static const int uploadBurstMax = 2;            // max 2 in any 30-second burst
  static const Duration uploadBurstWindow = Duration(seconds: 30);

  static const int geminiDailyLimit = 25;         // Edge Function enforces this
  static const Duration geminiCooldown = Duration(seconds: 3);

  // ── Client-Side Soft Rate Limits (UI guards — server always re-checks) ───
  static const int clientUploadPerMinute = 2;
  static const int clientCommentPerMinute = 5;
  static const int clientPostPerMinute = 3;
  static const int clientReportPerMinute = 3;
  static const int clientLoginPerMinute = 5;

  // ── AI Rate Limiting (client-side UI mirrors) ─────────────────────────────
  static const int dailyAiRequestLimit = 20;      // Client shows this limit
  static const Duration aiCooldownDuration = Duration(seconds: 3);

  // ── Input Length Limits ───────────────────────────────────────────────────
  static const int maxAiPromptLength = 1000;
  static const int maxBioLength = 300;
  static const int maxPostLength = 2000;
  static const int maxCommentLength = 500;
  static const int maxTitleLength = 120;
  static const int maxDescriptionLength = 500;
  static const int maxReportReasonLength = 500;
  static const int maxSupportTicketLength = 2000;
  static const int maxUsernameLength = 30;
  static const int maxSubjectLength = 100;

  // ── Cloudinary Config ─────────────────────────────────────────────────────
  // Note: Cloudinary cloud name and upload preset are not secret — they are
  // visible in all Cloudinary integrations. Security is enforced by:
  //   1. server-side scan-pdf validation before upload
  //   2. Cloudinary upload preset settings (PDF-only, max 20MB)
  //   3. Cloudinary folder isolation per user
  static const String cloudinaryCloudName = 'dgsvrdmze';
  static const String cloudinaryUploadPreset = 'studysphere_preset';
}
