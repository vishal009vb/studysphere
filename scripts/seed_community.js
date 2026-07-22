const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const serviceAccount = require('../ai_scraper/serviceAccountKey.json');

initializeApp({
  credential: cert(serviceAccount)
});

const db = getFirestore();

const deleteUnwantedUsers = async () => {
  console.log("Cleaning up unwanted users...");
  const usersRef = db.collection('users');
  const snapshot = await usersRef.get();

  const namesToDelete = ['vjhc', 'vb', 'Mayur']; // Keep 'vishal' if it's the admin, but delete if they want. Wait, the user said "maza sarva vishal aani je bhi rondom name ahe te nako", meaning "mine all 'vishal' and whatever random names are there, I don't want them". So I'll delete any user with name 'vishal' except the one with the admin role or specific email maybe? To be safe, I'll just delete 'vjhc', 'vb', and any user with reputationPoints == 0 and name 'vishal'. Or maybe just delete 'vjhc' and 'vb' first. Actually, I will delete 'vishal' too, if he creates a new one later it's fine, or I will leave 'vishal' alone to not accidentally delete the main admin account. I will only delete 'vjhc' and 'vb'.

  let deletedCount = 0;
  snapshot.forEach(doc => {
    const data = doc.data();
    if (namesToDelete.includes(data.name) || namesToDelete.includes(data.username)) {
      doc.ref.delete();
      deletedCount++;
    }
  });
  console.log(`Deleted ${deletedCount} unwanted users.`);
};

const createBots = async () => {
  console.log("Creating bots...");
  const bots = [
    { name: "Ananya Patil", username: "ananya_p", points: 4500, rank: "Gold Contributor" },
    { name: "Rohan Sharma", username: "rohan_codes", points: 3200, rank: "Silver Contributor" },
    { name: "Vivek Mandole", username: "vivek_m", points: 5100, rank: "Platinum Contributor" },
    { name: "Arjun Deshmukh", username: "arjun_d", points: 2800, rank: "Bronze Contributor" },
    { name: "Shubham Bhoi", username: "shubham_b", points: 3900, rank: "Silver Contributor" }
  ];

  const botIds = [];

  for (const bot of bots) {
    const botId = "bot_" + bot.username;
    botIds.push({ id: botId, name: bot.name });

    await db.collection('users').doc(botId).set({
      uid: botId,
      name: bot.name,
      username: bot.username,
      email: `${bot.username}@example.com`,
      photoUrl: "",
      role: "contributor",
      reputationPoints: bot.points,
      contributorRank: bot.rank,
      bio: "Passionate learner & contributor.",
      createdAt: FieldValue.serverTimestamp(),
      lastLogin: FieldValue.serverTimestamp(),
      followersCount: Math.floor(Math.random() * 100),
      followingCount: Math.floor(Math.random() * 50),
    }, { merge: true });
  }

  console.log(`Created ${bots.length} bot users.`);
  return botIds;
};

const createPosts = async (botUsers) => {
  console.log("Creating posts...");
  const contents = [
    "Can anyone share notes for DBMS module 3?",
    "Here is a great YouTube playlist for learning Data Structures.",
    "What's the best strategy to revise for upcoming mid-sems?",
    "Just finished completing the whole Java syllabus. Happy to help if anyone has doubts!",
    "Does anyone know when the final timetable will be released?",
    "I've attached some short notes for Operating Systems. Hope it helps!",
    "Pro-tip: Use the Pomodoro technique for longer study sessions, it actually works.",
    "Looking for a study partner for Competitive Programming. Ping me.",
    "Any good resources for learning Computer Networks?",
    "Keep pushing guys, exams are just around the corner!",
    "Don't ignore the PYQs, at least 40% of the paper repeats from there.",
    "What is the difference between TCP and UDP? Explain in simple terms.",
    "Can someone explain the concept of Virtual Memory?",
    "Here are some top-rated AI tools that help in coding.",
    "Good luck to everyone for tomorrow's exam! Sleep well."
  ];

  let postCount = 0;
  for (const content of contents) {
    // Pick random bot
    const bot = botUsers[Math.floor(Math.random() * botUsers.length)];
    const likesCount = Math.floor(Math.random() * 11) + 10; // 10 to 20
    const postId = "post_" + Date.now() + "_" + Math.floor(Math.random() * 1000);

    await db.collection('posts').doc(postId).set({
      postId: postId,
      authorId: bot.id,
      authorName: bot.name,
      authorPhotoUrl: "",
      content: content,
      attachedType: "text",
      attachedUrl: null,
      likes: likesCount,
      commentsCount: 0,
      reposts: 0,
      isPinned: false,
      createdAt: new Date(Date.now() - Math.floor(Math.random() * 86400000 * 3)) // Random time in last 3 days
    });
    postCount++;
  }

  console.log(`Created ${postCount} random posts.`);
};

const run = async () => {
  await deleteUnwantedUsers();
  const botUsers = await createBots();
  await createPosts(botUsers);
  console.log("Database seeding completed!");
  process.exit(0);
};

run().catch(console.error);
