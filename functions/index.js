const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { defineSecret } = require("firebase-functions/params");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const nodemailer = require("nodemailer");
const fs = require("fs");
const path = require("path");
require("dotenv").config();

initializeApp();

const db = getFirestore();

// ─── Secret: Gemini API key stored in Firebase Secret Manager ───────────────
// Deploy: firebase functions:secrets:set GEMINI_API_KEY
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

// ─── IST Timezone Helpers ────────────────────────────────────────────────────

/**
 * Returns today's date string in YYYY-MM-DD format, adjusted to IST (UTC+5:30).
 */
function getTodayIST() {
  const now = new Date();
  // IST offset: +5h30m = 330 minutes
  const istOffset = 5.5 * 60 * 60 * 1000;
  const istNow = new Date(now.getTime() + istOffset);
  const yyyy = istNow.getUTCFullYear();
  const mm = String(istNow.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(istNow.getUTCDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

// ─── Cloud Function 1: checkAndIncrementUsage ────────────────────────────────
//
// Called by Flutter BEFORE making an AI request.
// Returns: { allowed: boolean, remaining: number, resetDone: boolean }
//
// Security:
//   - Only authenticated users can call this.
//   - Uses Firestore transaction → race-condition safe.
//   - Only this function writes dailyUsageCount & lastResetDate on the user doc.
//   - Firestore rules block direct client writes to these fields.

exports.checkAndIncrementUsage = onCall(
  { secrets: [] }, // No secrets needed for this function
  async (request) => {
    // Must be authenticated
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const uid = request.auth.uid;
    const userRef = db.collection("users").doc(uid);
    const todayIST = getTodayIST();

    try {
      const result = await db.runTransaction(async (transaction) => {
        const userSnap = await transaction.get(userRef);
        if (!userSnap.exists) {
          throw new HttpsError("not-found", "User profile not found.");
        }

        const data = userSnap.data();
        const role = data.role || "learner";
        const dailyLimit = role === "learner" ? 20 : Infinity;

        // Check if we need to reset the count (new IST day)
        const lastResetDate = data.lastResetDate || "";
        const resetDone = lastResetDate !== todayIST;
        let currentCount = resetDone ? 0 : (data.dailyUsageCount || 0);

        if (currentCount >= dailyLimit) {
          return { allowed: false, remaining: 0, resetDone };
        }

        // Increment and persist
        const updates = {
          dailyUsageCount: currentCount + 1,
          lastResetDate: todayIST,
        };
        transaction.update(userRef, updates);

        return {
          allowed: true,
          remaining: dailyLimit === Infinity ? 9999 : dailyLimit - currentCount - 1,
          resetDone,
          newCount: currentCount + 1,
        };
      });

      return result;
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error("checkAndIncrementUsage error:", err);
      throw new HttpsError("internal", "Rate limit check failed. Try again.");
    }
  }
);

// ─── Cloud Function 2: askGeminiAI ──────────────────────────────────────────
//
// Main HTTPS callable. Flutter sends { question, context } and gets { answer }.
//
// Flow:
//   1. Verify authentication.
//   2. Call checkAndIncrementUsage internally (re-validates server-side).
//   3. Build educational system prompt.
//   4. Call Gemini API (key from Secret Manager).
//   5. Save Q&A to users/{uid}/chatHistory (subcollection).
//   6. Return answer to Flutter.

exports.askGeminiAI = onCall(
  {
    secrets: [GEMINI_API_KEY],
    timeoutSeconds: 60,
  },
  async (request) => {
    // 1. Auth check
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const uid = request.auth.uid;
    const question = (request.data.question || "").trim();
    const courseContext = request.data.courseContext || "";

    if (!question) {
      throw new HttpsError("invalid-argument", "Question cannot be empty.");
    }
    if (question.length > 2000) {
      throw new HttpsError("invalid-argument", "Question too long (max 2000 characters).");
    }

    // 2. Server-side rate limit re-validation (transaction-safe)
    const userRef = db.collection("users").doc(uid);
    const todayIST = getTodayIST();

    let rateLimitPassed = false;
    try {
      await db.runTransaction(async (transaction) => {
        const userSnap = await transaction.get(userRef);
        if (!userSnap.exists) throw new HttpsError("not-found", "User not found.");

        const data = userSnap.data();
        const role = data.role || "learner";
        const dailyLimit = role === "learner" ? 20 : Infinity;
        const lastResetDate = data.lastResetDate || "";
        const resetNeeded = lastResetDate !== todayIST;
        const currentCount = resetNeeded ? 0 : (data.dailyUsageCount || 0);

        if (currentCount >= dailyLimit) {
          throw new HttpsError(
            "resource-exhausted",
            "Daily limit reached. Upgrade to Contributor for unlimited access."
          );
        }

        transaction.update(userRef, {
          dailyUsageCount: currentCount + 1,
          lastResetDate: todayIST,
        });
        rateLimitPassed = true;
      });
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      throw new HttpsError("internal", "Rate limit validation failed.");
    }

    if (!rateLimitPassed) {
      throw new HttpsError("resource-exhausted", "Daily limit reached.");
    }

    // 3. Call Gemini API
    let answer = "";
    try {
      const genAI = new GoogleGenerativeAI(GEMINI_API_KEY.value());
      const model = genAI.getGenerativeModel({
        model: "gemini-1.5-flash",
        systemInstruction: `You are an expert AI Study Assistant for Indian students. 
You help with exam preparation, concept explanations, MCQ generation, and study roadmaps.
${courseContext ? `The student's current course/focus area: ${courseContext}.` : ""}
Always respond in a clear, educational, and encouraging tone.
Format responses with bullet points or numbered lists where applicable.
For MCQs, always include 4 options (A/B/C/D) and mark the correct answer.
Keep answers concise but complete — avoid unnecessary padding.`,
      });

      const result = await model.generateContent(question);
      const response = result.response;
      answer = response.text();

      if (!answer || answer.trim() === "") {
        answer = "I couldn't generate a response. Please rephrase your question and try again.";
      }
    } catch (geminiErr) {
      console.error("Gemini API error:", geminiErr);
      // Decrement usage count since the API call failed
      await userRef.update({
        dailyUsageCount: FieldValue.increment(-1),
      }).catch(() => {}); // Best-effort rollback

      if (geminiErr.message && geminiErr.message.includes("quota")) {
        throw new HttpsError(
          "resource-exhausted",
          "AI service quota exceeded. Please try again later."
        );
      }
      throw new HttpsError(
        "unavailable",
        "AI Assistant is temporarily unavailable. Please try again in a few minutes."
      );
    }

    // 4. Save to chat history subcollection (users/{uid}/chatHistory)
    const historyRef = db
      .collection("users")
      .doc(uid)
      .collection("chatHistory");

    const messageId = Date.now().toString();
    await historyRef.doc(messageId).set({
      messageId,
      question,
      answer,
      courseContext,
      timestamp: FieldValue.serverTimestamp(),
      sessionDate: todayIST,
    });

    // 5. Enforce retention: delete oldest if > 50 messages
    const countSnap = await historyRef.orderBy("timestamp", "asc").get();
    if (countSnap.size > 50) {
      const toDelete = countSnap.docs.slice(0, countSnap.size - 50);
      const batch = db.batch();
      toDelete.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
    }

    return { answer };
  }
);

// ─── Cloud Function 3: fetchChatHistory ─────────────────────────────────────
//
// Returns the last N messages from users/{uid}/chatHistory.

exports.fetchChatHistory = onCall(
  { secrets: [] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const uid = request.auth.uid;
    const limit = Math.min(request.data.limit || 20, 50);

    try {
      const snap = await db
        .collection("users")
        .doc(uid)
        .collection("chatHistory")
        .orderBy("timestamp", "desc")
        .limit(limit)
        .get();

      const messages = snap.docs.map((doc) => ({
        messageId: doc.id,
        question: doc.data().question,
        answer: doc.data().answer,
        timestamp: doc.data().timestamp?.toDate?.()?.toISOString() || null,
        sessionDate: doc.data().sessionDate,
      })).reverse(); // Chronological order

      return { messages };
    } catch (err) {
      console.error("fetchChatHistory error:", err);
      throw new HttpsError("internal", "Failed to fetch chat history.");
    }
  }
);

// ─── Cloud Function 4: cleanupOldChatHistory (Scheduled) ────────────────────
//
// Runs daily at 2:30 AM IST (21:00 UTC) to delete chat history older than 30 days.

exports.cleanupOldChatHistory = onSchedule(
  {
    schedule: "0 21 * * *", // 21:00 UTC = 2:30 AM IST
    timeZone: "Asia/Kolkata",
    timeoutSeconds: 540,
  },
  async (event) => {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - 30);

    console.log(`Cleaning chat history older than ${cutoffDate.toISOString()}`);

    // Get all users
    const usersSnap = await db.collection("users").select().get();
    let totalDeleted = 0;

    for (const userDoc of usersSnap.docs) {
      const uid = userDoc.id;
      const historyRef = db
        .collection("users")
        .doc(uid)
        .collection("chatHistory");

      // Delete messages older than 30 days
      const oldMessagesSnap = await historyRef
        .where("timestamp", "<", cutoffDate)
        .get();

      if (oldMessagesSnap.size > 0) {
        const batch = db.batch();
        oldMessagesSnap.docs.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
        totalDeleted += oldMessagesSnap.size;
      }
    }

    console.log(`Cleanup complete. Deleted ${totalDeleted} old chat messages.`);
  }
);

// ─── Cloud Function 5: sendWelcomeEmail ──────────────────────────────────────
//
// Triggered when a new user profile is created in Firestore.
// Sends a welcome email using nodemailer and the 2_welcome.html template.

const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: process.env.SMTP_EMAIL || "studysphere@gmail.com",
    pass: process.env.SMTP_PASSWORD || "",
  },
});

exports.sendWelcomeEmail = onDocumentCreated("users/{uid}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    console.log("No data associated with the event");
    return;
  }

  const userData = snapshot.data();
  const userEmail = userData.email;
  const userName = userData.name || "Student";

  if (!userEmail) {
    console.log("No email found for user:", event.params.uid);
    return;
  }

  try {
    // Read the HTML template
    const templatePath = path.join(__dirname, "email_templates", "2_welcome.html");
    let htmlContent = fs.readFileSync(templatePath, "utf-8");

    // Replace the placeholders
    htmlContent = htmlContent.replace(/%EMAIL%/g, userEmail);
    htmlContent = htmlContent.replace(/%NAME%/g, userName);

    const mailOptions = {
      from: `"StudySphere Team" <${process.env.SMTP_EMAIL || "studysphere@gmail.com"}>`,
      replyTo: process.env.SMTP_EMAIL || "studysphere@gmail.com",
      to: userEmail,
      subject: `Welcome to StudySphere, ${userName}! 🎉`,
      text: `Welcome to StudySphere, ${userName}! 🎉\n\nHello ${userName}! 👋\nThank you for choosing StudySphere. We're absolutely thrilled to have you on board. StudySphere is designed to revolutionize the way you learn, making it smarter, faster, and much more engaging.\n\nOpen the StudySphere app on your device to start learning!\n\nYou received this email because you registered on StudySphere.\nSent to ${userEmail}\n\nTip: Please add this email address to your contacts so our emails don't go to spam.\n\n© 2026 StudySphere. All rights reserved.`,
      html: htmlContent,
    };

    // Send the email
    const info = await transporter.sendMail(mailOptions);
    console.log("Welcome email sent successfully to", userEmail, "Message ID:", info.messageId);

  } catch (error) {
    console.error("Error sending welcome email to", userEmail, ":", error);
  }
});

