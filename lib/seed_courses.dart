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
    }
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
