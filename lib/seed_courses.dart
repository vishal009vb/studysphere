import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

Future<void> fixAllPlaylists() async {
  debugPrint('fixAllPlaylists executed.');
}

/// Seeds the built-in course catalogue.
///
/// This is a development/admin maintenance tool and is deliberately NOT called
/// during app startup. Release builds no-op unless [force] is set, so a normal
/// user launch can never delete, overwrite, or re-seed the `courses`
/// collection. Pass `force: true` only from an explicit admin action.
Future<void> seedUserProvidedCourses({bool force = false}) async {
  if (!kDebugMode && !force) {
    debugPrint('Course seeding skipped: release build without force flag.');
    return;
  }

  final db = FirebaseFirestore.instance;

  final courses = [
    // ──────────────── EXISTING COURSES (unchanged) ────────────────
    {
      "id": "c_prog_101",
      "title": "C Programming Full Course",
      "description": "Complete C Language Tutorial from Scratch for Beginners to Advanced by CodeWithHarry.",
      "thumbnailUrl": "https://i.ytimg.com/vi/ZSPZob_1TOk/hqdefault.jpg",
      "category": "Programming",
      "level": "All Levels",
      "duration": "15 Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PLu0W_9lII9aiXlHcLx-mDH1Qul38wD3aR",
      "channelName": "CodeWithHarry",
      "isFeatured": true,
      "order": 1,
      "modules": [
        {
          "id": "ZSPZob_1TOk",
          "title": "C Language 15-Hour Full Course (CodeWithHarry)",
          "youtubeVideoId": "ZSPZob_1TOk",
          "duration": "15:13:00"
        },
        {
          "id": "PLu0W_9lII9aiXlHcLx-mDH1Qul38wD3aR",
          "title": "CodeWithHarry C Language Complete Playlist (70+ Videos)",
          "youtubeVideoId": "ZSPZob_1TOk",
          "duration": "70+ Videos"
        }
      ]
    },
    {
      "id": "cpp_prog_102",
      "title": "C++ Programming Full Course",
      "description": "Complete C++ Tutorial in One Shot & Complete Playlist for Placements and GATE by College Wallah & Gate Smashers.",
      "thumbnailUrl": "https://i.ytimg.com/vi/e7sAf4SbS_g/hqdefault.jpg",
      "category": "Programming",
      "level": "All Levels",
      "duration": "11 Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PLxCzCOWd7aiF6yRNI5OHQsnUJQfl7Geqj",
      "channelName": "College Wallah / Gate Smashers",
      "isFeatured": true,
      "order": 2,
      "modules": [
        {
          "id": "e7sAf4SbS_g",
          "title": "Complete C++ Tutorial in One Shot (College Wallah)",
          "youtubeVideoId": "e7sAf4SbS_g",
          "duration": "11:44:00"
        },
        {
          "id": "ZzRT6pyROz4",
          "title": "C++ Full Tutorial 10 Hours (CoDing SeeKho)",
          "youtubeVideoId": "ZzRT6pyROz4",
          "duration": "10:35:00"
        },
        {
          "id": "PLxCzCOWd7aiF6yRNI5OHQsnUJQfl7Geqj",
          "title": "Gate Smashers C++ Complete Course Playlist (120+ Videos)",
          "youtubeVideoId": "e7sAf4SbS_g",
          "duration": "120+ Videos"
        }
      ]
    },
    {
      "id": "python_prog_103",
      "title": "Python Programming (100 Days & Full Course)",
      "description": "Master Python from Basics to Advanced with CodeWithHarry 100 Days of Code & Shradha Khapra (Apna College).",
      "thumbnailUrl": "https://i.ytimg.com/vi/gfxD6v14k88/hqdefault.jpg",
      "category": "Programming",
      "level": "All Levels",
      "duration": "12 Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PLu0W_9lII9agwh1XjRt242xIpHhPT2llg",
      "channelName": "CodeWithHarry / Apna College",
      "isFeatured": true,
      "order": 3,
      "modules": [
        {
          "id": "gfxD6v14k88",
          "title": "Python for Beginners - Full Course (CodeWithHarry)",
          "youtubeVideoId": "gfxD6v14k88",
          "duration": "12:00:00"
        },
        {
          "id": "PLu0W_9lII9agwh1XjRt242xIpHhPT2llg",
          "title": "Python 100 Days of Code Playlist (CodeWithHarry)",
          "youtubeVideoId": "gfxD6v14k88",
          "duration": "100 Videos"
        },
        {
          "id": "PLGjplNEQ1it8-0CmoljS5yeV-GlKSUEt0",
          "title": "Python Language Full Course Playlist (Apna College)",
          "youtubeVideoId": "gfxD6v14k88",
          "duration": "130+ Videos"
        }
      ]
    },
    {
      "id": "java_prog_104",
      "title": "Java Programming Masterclass",
      "description": "Comprehensive Java Programming in One Shot & Complete Placement Playlist by CoDing SeeKho, Anuj Sharma & CodeWithHarry.",
      "thumbnailUrl": "https://i.ytimg.com/vi/32DLasxoOiM/hqdefault.jpg",
      "category": "Programming",
      "level": "All Levels",
      "duration": "18 Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PLu0W_9lII9agS67Uits0UnJyrYiXhDS6q",
      "channelName": "CoDing SeeKho / Anuj Sharma / CodeWithHarry",
      "isFeatured": true,
      "order": 4,
      "modules": [
        {
          "id": "32DLasxoOiM",
          "title": "Java Programming Full Tutorial (CoDing SeeKho)",
          "youtubeVideoId": "32DLasxoOiM",
          "duration": "18:34:00"
        },
        {
          "id": "NNLoi8QqzaY",
          "title": "Complete Java in One Video (Anuj Kumar Sharma)",
          "youtubeVideoId": "NNLoi8QqzaY",
          "duration": "11:59:00"
        },
        {
          "id": "PLu0W_9lII9agS67Uits0UnJyrYiXhDS6q",
          "title": "CodeWithHarry Java Tutorials Complete Playlist",
          "youtubeVideoId": "32DLasxoOiM",
          "duration": "110+ Videos"
        }
      ]
    },
    {
      "id": "dsa_core_105",
      "title": "Data Structures & Algorithms (DSA)",
      "description": "Master DSA in C++ with College Wallah, WsCube Tech, and Apna College Complete Course.",
      "thumbnailUrl": "https://i.ytimg.com/vi/GRxzQXBwA-U/hqdefault.jpg",
      "category": "Core CS",
      "level": "All Levels",
      "duration": "11 Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PLfqMhTWNBTe137I_EPQd34TsgV6IO55pt",
      "channelName": "College Wallah / WsCube Tech / Apna College",
      "isFeatured": true,
      "order": 5,
      "modules": [
        {
          "id": "GRxzQXBwA-U",
          "title": "DSA in C++ in One Shot (College Wallah)",
          "youtubeVideoId": "GRxzQXBwA-U",
          "duration": "10:54:00"
        },
        {
          "id": "hCrO_cR7kno",
          "title": "DSA Full Course with Practical (WsCube Tech)",
          "youtubeVideoId": "hCrO_cR7kno",
          "duration": "09:11:00"
        },
        {
          "id": "PLfqMhTWNBTe137I_EPQd34TsgV6IO55pt",
          "title": "Apna College Complete C++ DSA Course Playlist",
          "youtubeVideoId": "GRxzQXBwA-U",
          "duration": "140+ Videos"
        }
      ]
    },
    {
      "id": "webdev_106",
      "title": "Web Development (HTML, CSS, JavaScript)",
      "description": "Learn Front-End & Full Stack Web Development with WsCube Tech, Intellipaat, and CodeWithHarry Sigma Course.",
      "thumbnailUrl": "https://i.ytimg.com/vi/jgfq8OybWZQ/hqdefault.jpg",
      "category": "Web Dev",
      "level": "All Levels",
      "duration": "10 Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PLu0W_9lII9agq5TrH9XLIKQvv0iaF2X3w",
      "channelName": "WsCube Tech / Intellipaat / CodeWithHarry",
      "isFeatured": true,
      "order": 6,
      "modules": [
        {
          "id": "jgfq8OybWZQ",
          "title": "Front End Web Development Full Course (WsCube Tech)",
          "youtubeVideoId": "jgfq8OybWZQ",
          "duration": "09:34:00"
        },
        {
          "id": "6d3lqsQfZSk",
          "title": "Web Development Full Course (Intellipaat)",
          "youtubeVideoId": "6d3lqsQfZSk",
          "duration": "10:05:00"
        },
        {
          "id": "PLu0W_9lII9agq5TrH9XLIKQvv0iaF2X3w",
          "title": "Sigma Web Development Course Playlist (CodeWithHarry)",
          "youtubeVideoId": "jgfq8OybWZQ",
          "duration": "130+ Videos"
        }
      ]
    },
    {
      "id": "dbms_107",
      "title": "Database Management System (DBMS + SQL)",
      "description": "Complete DBMS & SQL for University Exams and GATE by Sanchit Sir and 5 Minutes Engineering.",
      "thumbnailUrl": "https://i.ytimg.com/vi/FchQ6wZVqsA/hqdefault.jpg",
      "category": "Core CS",
      "level": "All Levels",
      "duration": "11 Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PLmXKhU9FNesR1rSES7oLdJaNFgmuj0SYV",
      "channelName": "KnowledgeGATE / 5 Minutes Engineering",
      "isFeatured": true,
      "order": 7,
      "modules": [
        {
          "id": "FchQ6wZVqsA",
          "title": "DBMS in One Shot (KnowledgeGATE Sanchit Sir)",
          "youtubeVideoId": "FchQ6wZVqsA",
          "duration": "11:37:00"
        },
        {
          "id": "jzuzxEFoiss",
          "title": "Complete DBMS Database Management (5 Minutes Engineering)",
          "youtubeVideoId": "jzuzxEFoiss",
          "duration": "05:36:00"
        },
        {
          "id": "PLmXKhU9FNesR1rSES7oLdJaNFgmuj0SYV",
          "title": "KnowledgeGATE DBMS In Hindi Playlist",
          "youtubeVideoId": "FchQ6wZVqsA",
          "duration": "130+ Videos"
        }
      ]
    },
    {
      "id": "os_108",
      "title": "Operating System (OS)",
      "description": "Master Operating Systems for University & Placements with Love Babbar, Sanchit Sir, and 5 Minutes Engineering.",
      "thumbnailUrl": "https://i.ytimg.com/vi/3obEP8eLsCw/hqdefault.jpg",
      "category": "Core CS",
      "level": "All Levels",
      "duration": "15 Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/watch?v=3obEP8eLsCw",
      "channelName": "Love Babbar / KnowledgeGATE / 5 Minutes Engineering",
      "isFeatured": true,
      "order": 8,
      "modules": [
        {
          "id": "3obEP8eLsCw",
          "title": "Complete Operating Systems in 1 Shot (Love Babbar)",
          "youtubeVideoId": "3obEP8eLsCw",
          "duration": "15:33:00"
        },
        {
          "id": "009FHqBo87Q",
          "title": "Operating System in One Shot (KnowledgeGATE Sanchit Sir)",
          "youtubeVideoId": "009FHqBo87Q",
          "duration": "11:56:00"
        },
        {
          "id": "A4G0hOI6XyQ",
          "title": "Complete OS (5 Minutes Engineering)",
          "youtubeVideoId": "A4G0hOI6XyQ",
          "duration": "07:01:00"
        }
      ]
    },
    {
      "id": "cn_109",
      "title": "Computer Networks (CN)",
      "description": "Learn Computer Networks in One Shot and Complete Playlist by 5 Minutes Engineering & Gate Smashers.",
      "thumbnailUrl": "https://i.ytimg.com/vi/1V9mhVgVH3A/hqdefault.jpg",
      "category": "Core CS",
      "level": "All Levels",
      "duration": "10 Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PLxCzCOWd7aiGFBD2-2joCpWOLUrDLvVV_",
      "channelName": "5 Minutes Engineering / Gate Smashers",
      "isFeatured": true,
      "order": 9,
      "modules": [
        {
          "id": "1V9mhVgVH3A",
          "title": "Complete Computer Networks in One Shot (5 Minutes Engineering)",
          "youtubeVideoId": "1V9mhVgVH3A",
          "duration": "10:31:00"
        },
        {
          "id": "PLxCzCOWd7aiGFBD2-2joCpWOLUrDLvVV_",
          "title": "Gate Smashers Computer Networks Playlist",
          "youtubeVideoId": "1V9mhVgVH3A",
          "duration": "130+ Videos"
        }
      ]
    },
    {
      "id": "se_110",
      "title": "Software Engineering",
      "description": "Complete Software Engineering for CS/IT Students by KnowledgeGATE Sanchit Sir and Gate Smashers.",
      "thumbnailUrl": "https://i.ytimg.com/vi/NlLM3sVF8wY/hqdefault.jpg",
      "category": "Core CS",
      "level": "All Levels",
      "duration": "6 Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PLxCzCOWd7aiEed7SKZBnC6ypFDWYLRvB2",
      "channelName": "KnowledgeGATE / Gate Smashers",
      "isFeatured": true,
      "order": 10,
      "modules": [
        {
          "id": "NlLM3sVF8wY",
          "title": "Complete Software Engineering in One Shot (KnowledgeGATE)",
          "youtubeVideoId": "NlLM3sVF8wY",
          "duration": "05:57:00"
        },
        {
          "id": "PLxCzCOWd7aiEed7SKZBnC6ypFDWYLRvB2",
          "title": "Gate Smashers Software Engineering Playlist",
          "youtubeVideoId": "NlLM3sVF8wY",
          "duration": "60+ Videos"
        }
      ]
    },

    // ──────────────── NEW: Web Development ────────────────
    {
      "id": "webdev_apna_111",
      "title": "Web Development Course - Apna College",
      "description": "Complete Web Development Course covering HTML, CSS, JavaScript, and more by Apna College (Shradha Khapra & Aman Dhattarwal).",
      "thumbnailUrl": "https://i.ytimg.com/vi/HcOc7P5BMi4/hqdefault.jpg",
      "category": "Web Dev",
      "level": "Beginner",
      "duration": "50+ Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PLfqMhTWNBTe3H6c9OGXb5_6wcc1Mca52n",
      "channelName": "Apna College",
      "isFeatured": true,
      "order": 11,
      "modules": [
        {
          "id": "HcOc7P5BMi4",
          "title": "Web Development Course - Apna College",
          "youtubeVideoId": "HcOc7P5BMi4",
          "duration": "50+ Hours"
        },
        {
          "id": "PLfqMhTWNBTe3H6c9OGXb5_6wcc1Mca52n",
          "title": "Apna College Web Development Playlist (150+ Videos)",
          "youtubeVideoId": "HcOc7P5BMi4",
          "duration": "150+ Videos"
        }
      ]
    },
    {
      "id": "webdev_mern_112",
      "title": "Full Stack Web Development - MERN Stack",
      "description": "Complete MERN Stack Full Stack Web Development Course by Web Dev Mastery — MongoDB, Express, React, Node.js.",
      "thumbnailUrl": "https://i.ytimg.com/vi/7fjOw8ApZ1I/hqdefault.jpg",
      "category": "Web Dev",
      "level": "Intermediate",
      "duration": "40+ Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PL-CeQccLavFeytqS_ALj97JNd4PF4gc1z",
      "channelName": "Web Dev Mastery",
      "isFeatured": false,
      "order": 12,
      "modules": [
        {
          "id": "7fjOw8ApZ1I",
          "title": "MERN Stack Full Course (Web Dev Mastery)",
          "youtubeVideoId": "7fjOw8ApZ1I",
          "duration": "40+ Hours"
        },
        {
          "id": "PL-CeQccLavFeytqS_ALj97JNd4PF4gc1z",
          "title": "MERN Stack Full Playlist",
          "youtubeVideoId": "7fjOw8ApZ1I",
          "duration": "100+ Videos"
        }
      ]
    },
    {
      "id": "webdev_stp_113",
      "title": "Web Development Full Course in Hindi - STP",
      "description": "Full Web Development Course in Hindi covering HTML, CSS, JS, PHP, MySQL by STP Computer Education.",
      "thumbnailUrl": "https://i.ytimg.com/vi/BsDoLVMnmZs/hqdefault.jpg",
      "category": "Web Dev",
      "level": "Beginner",
      "duration": "30+ Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PLwmDa-QvqlfjwxtXCuar4LAAsp1aL5YPv",
      "channelName": "STP Computer Education",
      "isFeatured": false,
      "order": 13,
      "modules": [
        {
          "id": "BsDoLVMnmZs",
          "title": "Web Development Full Course in Hindi (STP)",
          "youtubeVideoId": "BsDoLVMnmZs",
          "duration": "30+ Hours"
        },
        {
          "id": "PLwmDa-QvqlfjwxtXCuar4LAAsp1aL5YPv",
          "title": "STP Computer Education Web Dev Playlist",
          "youtubeVideoId": "BsDoLVMnmZs",
          "duration": "200+ Videos"
        }
      ]
    },
    {
      "id": "webdev_beginners_cwh_114",
      "title": "Beginners Web Dev (HTML, CSS, JS) - CodeWithHarry",
      "description": "Beginner-friendly Web Development course covering HTML, CSS and JavaScript basics by CodeWithHarry.",
      "thumbnailUrl": "https://i.ytimg.com/vi/BsDoLVMnmZs/hqdefault.jpg",
      "category": "Web Dev",
      "level": "Beginner",
      "duration": "20+ Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PLu0W_9lII9agiCUZYRsvtGTXdxkzPyItg",
      "channelName": "CodeWithHarry",
      "isFeatured": false,
      "order": 14,
      "modules": [
        {
          "id": "PLu0W_9lII9agiCUZYRsvtGTXdxkzPyItg",
          "title": "Beginners Web Dev Playlist - CodeWithHarry",
          "youtubeVideoId": "BsDoLVMnmZs",
          "duration": "80+ Videos"
        }
      ]
    },

    // ──────────────── NEW: App Development ────────────────
    {
      "id": "android_saumya_115",
      "title": "Android App Development Full Course",
      "description": "Complete Android App Development Course for Beginners by Saumya Singh — Java-based Android development from scratch.",
      "thumbnailUrl": "https://i.ytimg.com/vi/mXjZQX3UzOs/hqdefault.jpg",
      "category": "App Dev",
      "level": "Beginner",
      "duration": "30+ Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PLTV_nsuD2lf7JQvOmG9C-Nc4E0EL8DBoT",
      "channelName": "Saumya Singh",
      "isFeatured": true,
      "order": 15,
      "modules": [
        {
          "id": "mXjZQX3UzOs",
          "title": "Android App Development Full Course (Saumya Singh)",
          "youtubeVideoId": "mXjZQX3UzOs",
          "duration": "30+ Hours"
        },
        {
          "id": "PLTV_nsuD2lf7JQvOmG9C-Nc4E0EL8DBoT",
          "title": "Android Development Full Playlist (Saumya Singh)",
          "youtubeVideoId": "mXjZQX3UzOs",
          "duration": "100+ Videos"
        }
      ]
    },
    {
      "id": "flutter_dhruv_116",
      "title": "App Development Complete Course (Flutter)",
      "description": "Complete Flutter App Development Course by Code With Dhruv — build cross-platform Android & iOS apps with Dart & Flutter.",
      "thumbnailUrl": "https://i.ytimg.com/vi/VPvVD8t02U8/hqdefault.jpg",
      "category": "App Dev",
      "level": "Beginner",
      "duration": "35+ Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PLlvhNpz1tBvHVsPXhY3ipbYmkp9QPEQOj",
      "channelName": "Code With Dhruv",
      "isFeatured": true,
      "order": 16,
      "modules": [
        {
          "id": "VPvVD8t02U8",
          "title": "Flutter Complete Course (Code With Dhruv)",
          "youtubeVideoId": "VPvVD8t02U8",
          "duration": "35+ Hours"
        },
        {
          "id": "PLlvhNpz1tBvHVsPXhY3ipbYmkp9QPEQOj",
          "title": "Flutter App Development Full Playlist",
          "youtubeVideoId": "VPvVD8t02U8",
          "duration": "120+ Videos"
        }
      ]
    },
    {
      "id": "android_cwh_117",
      "title": "Android Development Tutorials in Hindi - CodeWithHarry",
      "description": "Learn Android App Development step-by-step in Hindi with CodeWithHarry — perfect for beginners.",
      "thumbnailUrl": "https://i.ytimg.com/vi/aS__9RbCyHg/hqdefault.jpg",
      "category": "App Dev",
      "level": "Beginner",
      "duration": "25+ Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PLu0W_9lII9aiL0kysYlfSOUgY5rNlOhUd",
      "channelName": "CodeWithHarry",
      "isFeatured": false,
      "order": 17,
      "modules": [
        {
          "id": "aS__9RbCyHg",
          "title": "Android Development in Hindi (CodeWithHarry)",
          "youtubeVideoId": "aS__9RbCyHg",
          "duration": "25+ Hours"
        },
        {
          "id": "PLu0W_9lII9aiL0kysYlfSOUgY5rNlOhUd",
          "title": "CodeWithHarry Android Development Playlist",
          "youtubeVideoId": "aS__9RbCyHg",
          "duration": "80+ Videos"
        }
      ]
    },
    {
      "id": "android_kotlin_118",
      "title": "Android Development with Kotlin - Zain Farhan",
      "description": "Modern Android App Development using Kotlin by Zain Farhan — covers Kotlin fundamentals, UI, APIs & more.",
      "thumbnailUrl": "https://i.ytimg.com/vi/EExSSotojVI/hqdefault.jpg",
      "category": "App Dev",
      "level": "Intermediate",
      "duration": "30+ Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PL6Fr59UplGvL7q7P3Hg6nYzS45gld-CCI",
      "channelName": "Zain Farhan",
      "isFeatured": false,
      "order": 18,
      "modules": [
        {
          "id": "EExSSotojVI",
          "title": "Android with Kotlin Full Course (Zain Farhan)",
          "youtubeVideoId": "EExSSotojVI",
          "duration": "30+ Hours"
        },
        {
          "id": "PL6Fr59UplGvL7q7P3Hg6nYzS45gld-CCI",
          "title": "Android Kotlin Development Playlist",
          "youtubeVideoId": "EExSSotojVI",
          "duration": "100+ Videos"
        }
      ]
    },

    // ──────────────── NEW: Game Development ────────────────
    {
      "id": "gamedev_ue5_119",
      "title": "Unreal Engine 5 Game Development (Hindi/Urdu)",
      "description": "Learn Unreal Engine 5 game development from scratch in Hindi/Urdu by Nafay 3D — create stunning 3D games.",
      "thumbnailUrl": "https://i.ytimg.com/vi/k-zMkzmduqI/hqdefault.jpg",
      "category": "Game Dev",
      "level": "Beginner",
      "duration": "40+ Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PLULbDkdbO4tqCMcwjU0ab8uR5-2HpnZD8",
      "channelName": "Nafay 3D",
      "isFeatured": true,
      "order": 19,
      "modules": [
        {
          "id": "k-zMkzmduqI",
          "title": "Unreal Engine 5 Full Course in Hindi (Nafay 3D)",
          "youtubeVideoId": "k-zMkzmduqI",
          "duration": "40+ Hours"
        },
        {
          "id": "PLULbDkdbO4tqCMcwjU0ab8uR5-2HpnZD8",
          "title": "UE5 Hindi Game Dev Playlist",
          "youtubeVideoId": "k-zMkzmduqI",
          "duration": "80+ Videos"
        }
      ]
    },
    {
      "id": "gamedev_basit_120",
      "title": "Game Development - Beginner to Advanced",
      "description": "Complete Game Development course from Beginner to Advanced by Basit Ali's Trainings — covers multiple game engines.",
      "thumbnailUrl": "https://i.ytimg.com/vi/pwZpJzpE2lQ/hqdefault.jpg",
      "category": "Game Dev",
      "level": "All Levels",
      "duration": "50+ Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PL_sNHTasDRUH795JUNlF6ruwwn08Qg-nI",
      "channelName": "Basit Ali's Trainings",
      "isFeatured": false,
      "order": 20,
      "modules": [
        {
          "id": "pwZpJzpE2lQ",
          "title": "Game Development Beginner to Advanced (Basit Ali)",
          "youtubeVideoId": "pwZpJzpE2lQ",
          "duration": "50+ Hours"
        },
        {
          "id": "PL_sNHTasDRUH795JUNlF6ruwwn08Qg-nI",
          "title": "Game Dev Beginner to Advanced Playlist",
          "youtubeVideoId": "pwZpJzpE2lQ",
          "duration": "150+ Videos"
        }
      ]
    },
    {
      "id": "gamedev_unity_sunny_121",
      "title": "Your First Game in Unity - Sunny Gamedev",
      "description": "Build your first Unity game with Sunny Gamedev — beginner-friendly Unity 3D/2D game development tutorials.",
      "thumbnailUrl": "https://i.ytimg.com/vi/XtQMytORBmM/hqdefault.jpg",
      "category": "Game Dev",
      "level": "Beginner",
      "duration": "20+ Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PLCqWuVe6WFLJW4urlRk1501OkAGVQtX8q",
      "channelName": "Sunny Gamedev",
      "isFeatured": false,
      "order": 21,
      "modules": [
        {
          "id": "XtQMytORBmM",
          "title": "First Game in Unity (Sunny Gamedev)",
          "youtubeVideoId": "XtQMytORBmM",
          "duration": "20+ Hours"
        },
        {
          "id": "PLCqWuVe6WFLJW4urlRk1501OkAGVQtX8q",
          "title": "Unity Game Dev Playlist (Sunny Gamedev)",
          "youtubeVideoId": "XtQMytORBmM",
          "duration": "60+ Videos"
        }
      ]
    },
    {
      "id": "gamedev_farhan_122",
      "title": "Game Development Course - Farhan Aqeel",
      "description": "Comprehensive Game Development Course by Farhan Aqeel covering game design, Unity, and programming fundamentals.",
      "thumbnailUrl": "https://i.ytimg.com/vi/MBuBhYMgWS8/hqdefault.jpg",
      "category": "Game Dev",
      "level": "Beginner",
      "duration": "25+ Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PLBh8phtAyHPUY9fqgs1w6aHJALJ3_fMSc",
      "channelName": "Farhan Aqeel",
      "isFeatured": false,
      "order": 22,
      "modules": [
        {
          "id": "MBuBhYMgWS8",
          "title": "Game Development Full Course (Farhan Aqeel)",
          "youtubeVideoId": "MBuBhYMgWS8",
          "duration": "25+ Hours"
        },
        {
          "id": "PLBh8phtAyHPUY9fqgs1w6aHJALJ3_fMSc",
          "title": "Game Development Playlist (Farhan Aqeel)",
          "youtubeVideoId": "MBuBhYMgWS8",
          "duration": "80+ Videos"
        }
      ]
    },

    // ──────────────── NEW: DSA ────────────────
    {
      "id": "dsa_cwh_123",
      "title": "DSA in Hindi - CodeWithHarry",
      "description": "Complete DSA Course in Hindi by CodeWithHarry — Arrays, Linked Lists, Trees, Graphs, Sorting, Searching & more.",
      "thumbnailUrl": "https://i.ytimg.com/vi/5_5oE5lgrhw/hqdefault.jpg",
      "category": "DSA",
      "level": "All Levels",
      "duration": "30+ Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PLu0W_9lII9ahIappRPN0MCAgtOu3lQjQi",
      "channelName": "CodeWithHarry",
      "isFeatured": true,
      "order": 23,
      "modules": [
        {
          "id": "5_5oE5lgrhw",
          "title": "DSA Full Course in Hindi (CodeWithHarry)",
          "youtubeVideoId": "5_5oE5lgrhw",
          "duration": "30+ Hours"
        },
        {
          "id": "PLu0W_9lII9ahIappRPN0MCAgtOu3lQjQi",
          "title": "DSA Complete Course Playlist (CodeWithHarry)",
          "youtubeVideoId": "5_5oE5lgrhw",
          "duration": "100+ Videos"
        }
      ]
    },
    {
      "id": "dsa_durgesh_124",
      "title": "Complete DSA Course - Learn Code With Durgesh",
      "description": "Full DSA course in Hindi by Learn Code With Durgesh — great for placement preparation.",
      "thumbnailUrl": "https://i.ytimg.com/vi/AT14lCXuMKI/hqdefault.jpg",
      "category": "DSA",
      "level": "All Levels",
      "duration": "25+ Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PL0zysOflRCel693wumX2pbb-Zvi-5Ctea",
      "channelName": "Learn Code With Durgesh",
      "isFeatured": false,
      "order": 24,
      "modules": [
        {
          "id": "AT14lCXuMKI",
          "title": "DSA Complete Course (Learn Code With Durgesh)",
          "youtubeVideoId": "AT14lCXuMKI",
          "duration": "25+ Hours"
        },
        {
          "id": "PL0zysOflRCel693wumX2pbb-Zvi-5Ctea",
          "title": "DSA Hindi Playlist (Durgesh)",
          "youtubeVideoId": "AT14lCXuMKI",
          "duration": "80+ Videos"
        }
      ]
    },
    {
      "id": "dsa_java_smart_125",
      "title": "DSA using Java - Placement Course (Smart Programming)",
      "description": "Data Structures & Algorithms using Java for placement preparation by Smart Programming — covers all important topics.",
      "thumbnailUrl": "https://i.ytimg.com/vi/5bId3N7QZec/hqdefault.jpg",
      "category": "DSA",
      "level": "Intermediate",
      "duration": "40+ Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PLlhM4lkb2sEjyqHABtdVXppkbN7-SDJ_-",
      "channelName": "Smart Programming",
      "isFeatured": false,
      "order": 25,
      "modules": [
        {
          "id": "5bId3N7QZec",
          "title": "DSA using Java Placement Course (Smart Programming)",
          "youtubeVideoId": "5bId3N7QZec",
          "duration": "40+ Hours"
        },
        {
          "id": "PLlhM4lkb2sEjyqHABtdVXppkbN7-SDJ_-",
          "title": "Java DSA Placement Playlist (Smart Programming)",
          "youtubeVideoId": "5bId3N7QZec",
          "duration": "200+ Videos"
        }
      ]
    },

    // ──────────────── NEW: BCA/B.Tech Core Subjects ────────────────
    {
      "id": "dbms_gate_smashers_126",
      "title": "DBMS Complete Course - Gate Smashers",
      "description": "Database Management System complete course by Gate Smashers — all DBMS topics for GATE, university exams & interviews.",
      "thumbnailUrl": "https://i.ytimg.com/vi/kBdlM6hNDAE/hqdefault.jpg",
      "category": "Core CS",
      "level": "All Levels",
      "duration": "15+ Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PLxCzCOWd7aiFAN6I8CuViBuCdJgiOkT2Y",
      "channelName": "Gate Smashers",
      "isFeatured": false,
      "order": 26,
      "modules": [
        {
          "id": "kBdlM6hNDAE",
          "title": "DBMS Complete Course (Gate Smashers)",
          "youtubeVideoId": "kBdlM6hNDAE",
          "duration": "15+ Hours"
        },
        {
          "id": "PLxCzCOWd7aiFAN6I8CuViBuCdJgiOkT2Y",
          "title": "Gate Smashers DBMS Full Playlist",
          "youtubeVideoId": "kBdlM6hNDAE",
          "duration": "130+ Videos"
        }
      ]
    },
    {
      "id": "os_gate_smashers_127",
      "title": "Operating System - Gate Smashers",
      "description": "Complete Operating System course by Gate Smashers — ideal for GATE, university exams and placement interviews.",
      "thumbnailUrl": "https://i.ytimg.com/vi/bkSWJJZNgf8/hqdefault.jpg",
      "category": "Core CS",
      "level": "All Levels",
      "duration": "12+ Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PLxCzCOWd7aiGz9donHRrE9I3Mwn6XdP8p",
      "channelName": "Gate Smashers",
      "isFeatured": false,
      "order": 27,
      "modules": [
        {
          "id": "bkSWJJZNgf8",
          "title": "Operating System Full Course (Gate Smashers)",
          "youtubeVideoId": "bkSWJJZNgf8",
          "duration": "12+ Hours"
        },
        {
          "id": "PLxCzCOWd7aiGz9donHRrE9I3Mwn6XdP8p",
          "title": "Gate Smashers OS Full Playlist",
          "youtubeVideoId": "bkSWJJZNgf8",
          "duration": "120+ Videos"
        }
      ]
    },
    {
      "id": "os_knowledgegate_128",
      "title": "Operating System - KnowledgeGATE",
      "description": "Complete Operating System course by KnowledgeGATE (Sanchit Jain) — detailed theory with visual explanations.",
      "thumbnailUrl": "https://i.ytimg.com/vi/xw_OuOhjauw/hqdefault.jpg",
      "category": "Core CS",
      "level": "All Levels",
      "duration": "12+ Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PLmXKhU9FNesSFvj6gASuWmQd23Ul5omtD",
      "channelName": "KnowledgeGATE",
      "isFeatured": false,
      "order": 28,
      "modules": [
        {
          "id": "xw_OuOhjauw",
          "title": "Operating System Complete (KnowledgeGATE)",
          "youtubeVideoId": "xw_OuOhjauw",
          "duration": "12+ Hours"
        },
        {
          "id": "PLmXKhU9FNesSFvj6gASuWmQd23Ul5omtD",
          "title": "KnowledgeGATE OS Full Playlist",
          "youtubeVideoId": "xw_OuOhjauw",
          "duration": "100+ Videos"
        }
      ]
    },
    {
      "id": "cn_neso_129",
      "title": "Computer Networks - Neso Academy",
      "description": "Complete Computer Networks course by Neso Academy — OSI model, TCP/IP, routing, subnetting and more with animations.",
      "thumbnailUrl": "https://i.ytimg.com/vi/VwN91x5i25g/hqdefault.jpg",
      "category": "Core CS",
      "level": "All Levels",
      "duration": "20+ Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PLBlnK6fEyqRgMCUAG0XRw78UA8qnv6jEx",
      "channelName": "Neso Academy",
      "isFeatured": true,
      "order": 29,
      "modules": [
        {
          "id": "VwN91x5i25g",
          "title": "Computer Networks Full Course (Neso Academy)",
          "youtubeVideoId": "VwN91x5i25g",
          "duration": "20+ Hours"
        },
        {
          "id": "PLBlnK6fEyqRgMCUAG0XRw78UA8qnv6jEx",
          "title": "Neso Academy CN Full Playlist",
          "youtubeVideoId": "VwN91x5i25g",
          "duration": "200+ Videos"
        }
      ]
    },

    // ──────────────── NEW: Advanced Technology ────────────────
    {
      "id": "ai_gate_smashers_130",
      "title": "Artificial Intelligence - Gate Smashers",
      "description": "Complete AI course by Gate Smashers — search algorithms, knowledge representation, ML basics & more.",
      "thumbnailUrl": "https://i.ytimg.com/vi/Yup5k3kLSvo/hqdefault.jpg",
      "category": "AI/ML",
      "level": "All Levels",
      "duration": "15+ Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PLxCzCOWd7aiHGhOHV-nwb0HR5US5GFKFI",
      "channelName": "Gate Smashers",
      "isFeatured": true,
      "order": 30,
      "modules": [
        {
          "id": "Yup5k3kLSvo",
          "title": "Artificial Intelligence Full Course (Gate Smashers)",
          "youtubeVideoId": "Yup5k3kLSvo",
          "duration": "15+ Hours"
        },
        {
          "id": "PLxCzCOWd7aiHGhOHV-nwb0HR5US5GFKFI",
          "title": "Gate Smashers AI Full Playlist",
          "youtubeVideoId": "Yup5k3kLSvo",
          "duration": "80+ Videos"
        }
      ]
    },
    {
      "id": "ml_wscube_131",
      "title": "Machine Learning with Projects - WsCube Tech",
      "description": "Complete Machine Learning course with real-world projects by WsCube Tech — Python, Scikit-learn, EDA, ML Algorithms.",
      "thumbnailUrl": "https://i.ytimg.com/vi/bPrmA1SEN2k/hqdefault.jpg",
      "category": "AI/ML",
      "level": "Intermediate",
      "duration": "40+ Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PLjVLYmrlmjGe-xLyoCdDrt8Nil1Alg_L3",
      "channelName": "WsCube Tech",
      "isFeatured": true,
      "order": 31,
      "modules": [
        {
          "id": "bPrmA1SEN2k",
          "title": "Machine Learning Full Course with Projects (WsCube Tech)",
          "youtubeVideoId": "bPrmA1SEN2k",
          "duration": "40+ Hours"
        },
        {
          "id": "PLjVLYmrlmjGe-xLyoCdDrt8Nil1Alg_L3",
          "title": "WsCube ML Full Playlist",
          "youtubeVideoId": "bPrmA1SEN2k",
          "duration": "150+ Videos"
        }
      ]
    },
    {
      "id": "ml_krish_132",
      "title": "Machine Learning Tutorial - Krish Naik Hindi",
      "description": "Machine Learning complete tutorial in Hindi by Krish Naik — ML algorithms, Deep Learning, NLP with practical implementations.",
      "thumbnailUrl": "https://i.ytimg.com/vi/z8sxaUw_f-M/hqdefault.jpg",
      "category": "AI/ML",
      "level": "Intermediate",
      "duration": "30+ Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PLTDARY42LDV7WGmlzZtY-w9pemyPrKNUZ",
      "channelName": "Krish Naik Hindi",
      "isFeatured": false,
      "order": 32,
      "modules": [
        {
          "id": "z8sxaUw_f-M",
          "title": "Machine Learning Hindi Tutorial (Krish Naik)",
          "youtubeVideoId": "z8sxaUw_f-M",
          "duration": "30+ Hours"
        },
        {
          "id": "PLTDARY42LDV7WGmlzZtY-w9pemyPrKNUZ",
          "title": "Krish Naik ML Hindi Playlist",
          "youtubeVideoId": "z8sxaUw_f-M",
          "duration": "100+ Videos"
        }
      ]
    },
    {
      "id": "cloud_gate_smashers_133",
      "title": "Cloud Computing Complete Course - Gate Smashers",
      "description": "Complete Cloud Computing course by Gate Smashers — cloud concepts, deployment models, IaaS/PaaS/SaaS & security.",
      "thumbnailUrl": "https://i.ytimg.com/vi/M988_fsOSWo/hqdefault.jpg",
      "category": "Cloud",
      "level": "All Levels",
      "duration": "12+ Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PLxCzCOWd7aiHRHVUtR-O52MsrdUSrzuy4",
      "channelName": "Gate Smashers",
      "isFeatured": true,
      "order": 33,
      "modules": [
        {
          "id": "M988_fsOSWo",
          "title": "Cloud Computing Full Course (Gate Smashers)",
          "youtubeVideoId": "M988_fsOSWo",
          "duration": "12+ Hours"
        },
        {
          "id": "PLxCzCOWd7aiHRHVUtR-O52MsrdUSrzuy4",
          "title": "Gate Smashers Cloud Computing Playlist",
          "youtubeVideoId": "M988_fsOSWo",
          "duration": "60+ Videos"
        }
      ]
    },
    {
      "id": "aws_techzeen_134",
      "title": "Cloud Computing with AWS - The Techzeen",
      "description": "Hands-on AWS Cloud Computing course by The Techzeen — EC2, S3, Lambda, RDS, IAM & real-world deployment.",
      "thumbnailUrl": "https://i.ytimg.com/vi/k1RI5locZE4/hqdefault.jpg",
      "category": "Cloud",
      "level": "Beginner",
      "duration": "20+ Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PL5OhSdfH4uDvRnoB9kAjDbhSlzUC2TIO2",
      "channelName": "The Techzeen",
      "isFeatured": false,
      "order": 34,
      "modules": [
        {
          "id": "k1RI5locZE4",
          "title": "AWS Cloud Computing Full Course (The Techzeen)",
          "youtubeVideoId": "k1RI5locZE4",
          "duration": "20+ Hours"
        },
        {
          "id": "PL5OhSdfH4uDvRnoB9kAjDbhSlzUC2TIO2",
          "title": "AWS Cloud Playlist (The Techzeen)",
          "youtubeVideoId": "k1RI5locZE4",
          "duration": "80+ Videos"
        }
      ]
    },
    {
      "id": "cybersec_wscube_135",
      "title": "Cyber Security Full Course - WsCube Tech",
      "description": "Complete Cyber Security course by WsCube Tech — ethical hacking, network security, cryptography, and cyber threats.",
      "thumbnailUrl": "https://i.ytimg.com/vi/nzZkKoREEGo/hqdefault.jpg",
      "category": "Cyber Security",
      "level": "All Levels",
      "duration": "20+ Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PLwO5-rumi8A7RnPxB6Zx0wKFjFy75hCQs",
      "channelName": "WsCube Tech",
      "isFeatured": true,
      "order": 35,
      "modules": [
        {
          "id": "nzZkKoREEGo",
          "title": "Cyber Security Full Course (WsCube Tech)",
          "youtubeVideoId": "nzZkKoREEGo",
          "duration": "20+ Hours"
        },
        {
          "id": "PLwO5-rumi8A7RnPxB6Zx0wKFjFy75hCQs",
          "title": "WsCube Tech Cyber Security Playlist",
          "youtubeVideoId": "nzZkKoREEGo",
          "duration": "100+ Videos"
        }
      ]
    },
    {
      "id": "ethicalhacking_cyberpathshala_136",
      "title": "Ethical Hacking Full Course - Cyber Pathshala",
      "description": "Complete Ethical Hacking course by Cyber Pathshala — penetration testing, Kali Linux, reconnaissance, exploitation & more.",
      "thumbnailUrl": "https://i.ytimg.com/vi/dz_mCDxGMSk/hqdefault.jpg",
      "category": "Cyber Security",
      "level": "All Levels",
      "duration": "25+ Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PLH3sDJc7TmvsdwYcFMlci_2p65m-nTLB9",
      "channelName": "Cyber Pathshala",
      "isFeatured": false,
      "order": 36,
      "modules": [
        {
          "id": "dz_mCDxGMSk",
          "title": "Ethical Hacking Full Course (Cyber Pathshala)",
          "youtubeVideoId": "dz_mCDxGMSk",
          "duration": "25+ Hours"
        },
        {
          "id": "PLH3sDJc7TmvsdwYcFMlci_2p65m-nTLB9",
          "title": "Ethical Hacking Full Playlist (Cyber Pathshala)",
          "youtubeVideoId": "dz_mCDxGMSk",
          "duration": "80+ Videos"
        }
      ]
    },

    // ──────────────── NEW: Programming (C by Complete Coding) ────────────────
    {
      "id": "c_complete_coding_137",
      "title": "C Programming Complete Course - Complete Coding",
      "description": "Complete C Programming course by Complete Coding — covers all fundamentals of C language for beginners.",
      "thumbnailUrl": "https://i.ytimg.com/vi/irqbmMNs2Bo/hqdefault.jpg",
      "category": "Programming",
      "level": "Beginner",
      "duration": "20+ Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PL78RhpUUKSwcgBrlBtstLjBMEtQmCRbHp",
      "channelName": "Complete Coding",
      "isFeatured": false,
      "order": 37,
      "modules": [
        {
          "id": "irqbmMNs2Bo",
          "title": "C Programming Complete Course (Complete Coding)",
          "youtubeVideoId": "irqbmMNs2Bo",
          "duration": "20+ Hours"
        },
        {
          "id": "PL78RhpUUKSwcgBrlBtstLjBMEtQmCRbHp",
          "title": "Complete Coding C Programming Playlist",
          "youtubeVideoId": "irqbmMNs2Bo",
          "duration": "100+ Videos"
        }
      ]
    },

    // ──────────────── NEW: Java + DSA Placement ────────────────
    {
      "id": "java_dsa_apna_138",
      "title": "Java & DSA Course for Placement - Apna College",
      "description": "Complete Java + Data Structures & Algorithms for placement by Apna College — industry-level content.",
      "thumbnailUrl": "https://i.ytimg.com/vi/yRpLlJmRo2w/hqdefault.jpg",
      "category": "DSA",
      "level": "Intermediate",
      "duration": "60+ Hours",
      "youtubePlaylistUrl": "https://www.youtube.com/playlist?list=PLfqMhTWNBTe3LtFWcvwpqTkUSlB32kJop",
      "channelName": "Apna College",
      "isFeatured": true,
      "order": 38,
      "modules": [
        {
          "id": "yRpLlJmRo2w",
          "title": "Java & DSA Placement Course (Apna College)",
          "youtubeVideoId": "yRpLlJmRo2w",
          "duration": "60+ Hours"
        },
        {
          "id": "PLfqMhTWNBTe3LtFWcvwpqTkUSlB32kJop",
          "title": "Apna College Java DSA Placement Playlist",
          "youtubeVideoId": "yRpLlJmRo2w",
          "duration": "300+ Videos"
        }
      ]
    },
  ];

  try {
    // Upsert only. The previous implementation deleted every document in the
    // collection first, which destroyed admin-created courses, wiped the
    // isVisible/isDeleted/isPaid moderation flags, and reset createdAt on
    // every run.
    final batch = db.batch();

    for (final course in courses) {
      final docId = course['id'] as String;
      final data = {
        'title': course['title'],
        'description': course['description'],
        'thumbnailUrl': course['thumbnailUrl'],
        'category': course['category'],
        'level': course['level'],
        'duration': course['duration'],
        'youtubePlaylistUrl': course['youtubePlaylistUrl'],
        'channelName': course['channelName'],
        'isFeatured': course['isFeatured'],
        'order': course['order'],
        'modules': course['modules'],
        'totalVideos': (course['modules'] as List).length,
      };

      // merge:true preserves moderation flags and the original createdAt.
      batch.set(db.collection('courses').doc(docId), data, SetOptions(merge: true));
    }

    // One commit instead of 10 sequential round-trips.
    await batch.commit();
    debugPrint('SUCCESS: ${courses.length} courses upserted (merge, non-destructive).');
  } catch (e) {
    debugPrint('Error seeding courses: $e');
  }
}
