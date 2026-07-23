import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://firestore.googleapis.com/v1/projects/studysphere-app-3a480/databases/(default)/documents/courses';

  print('Fetching existing courses to prevent duplicates...');
  final listResp = await http.get(Uri.parse(baseUrl));
  final existingTitles = <String>{};
  
  if (listResp.statusCode == 200) {
    final data = jsonDecode(listResp.body);
    final docs = data['documents'] as List?;
    if (docs != null) {
      for (final doc in docs) {
        final fields = doc['fields'] as Map<String, dynamic>?;
        if (fields != null && fields.containsKey('title')) {
          final t = fields['title']?['stringValue'] as String?;
          if (t != null) existingTitles.add(t.toLowerCase().trim());
        }
      }
    }
  }

  print('Existing Course Titles in Firestore: $existingTitles');

  final newCourses = [
    {
      "title": "C Programming Masterclass",
      "description": "Complete C Language Tutorial from Scratch for Beginners to Advanced by CodeWithHarry.",
      "thumbnailUrl": "https://img.youtube.com/vi/ZSPZob_1TOk/hqdefault.jpg",
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
          "title": "CodeWithHarry C Language Complete Playlist",
          "youtubeVideoId": "ZSPZob_1TOk",
          "duration": "70+ Videos"
        }
      ]
    },
    {
      "title": "C++ Programming Full Course",
      "description": "Complete C++ Tutorial in One Shot & Complete Playlist for Placements and GATE by College Wallah & Gate Smashers.",
      "thumbnailUrl": "https://img.youtube.com/vi/e7sAf4SbS_g/hqdefault.jpg",
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
          "title": "Gate Smashers C++ Complete Course Playlist",
          "youtubeVideoId": "e7sAf4SbS_g",
          "duration": "120+ Videos"
        }
      ]
    },
    {
      "title": "Python Programming (100 Days & Full Course)",
      "description": "Master Python from Basics to Advanced with CodeWithHarry 100 Days of Code & Shradha Khapra (Apna College).",
      "thumbnailUrl": "https://img.youtube.com/vi/gfxD6v14k88/hqdefault.jpg",
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
      "title": "Java Programming Masterclass",
      "description": "Comprehensive Java Programming in One Shot & Complete Placement Playlist by CoDing SeeKho, Anuj Sharma & CodeWithHarry.",
      "thumbnailUrl": "https://img.youtube.com/vi/32DLasxoOiM/hqdefault.jpg",
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
      "title": "Data Structures & Algorithms (DSA)",
      "description": "Master DSA in C++ with College Wallah, WsCube Tech, and Apna College Complete Course.",
      "thumbnailUrl": "https://img.youtube.com/vi/GRxzQXBwA-U/hqdefault.jpg",
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
      "title": "Web Development (HTML, CSS, JavaScript)",
      "description": "Learn Front-End & Full Stack Web Development with WsCube Tech, Intellipaat, and CodeWithHarry Sigma Course.",
      "thumbnailUrl": "https://img.youtube.com/vi/jgfq8OybWZQ/hqdefault.jpg",
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
      "title": "Database Management System (DBMS + SQL)",
      "description": "Complete DBMS & SQL for University Exams and GATE by Sanchit Sir and 5 Minutes Engineering.",
      "thumbnailUrl": "https://img.youtube.com/vi/FchQ6wZVqsA/hqdefault.jpg",
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
      "title": "Operating System (OS)",
      "description": "Master Operating Systems for University & Placements with Love Babbar, Sanchit Sir, and 5 Minutes Engineering.",
      "thumbnailUrl": "https://img.youtube.com/vi/3obEP8eLsCw/hqdefault.jpg",
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
      "title": "Computer Networks (CN)",
      "description": "Learn Computer Networks in One Shot and Complete Playlist by 5 Minutes Engineering & Gate Smashers.",
      "thumbnailUrl": "https://img.youtube.com/vi/1V9mhVgVH3A/hqdefault.jpg",
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
      "title": "Software Engineering",
      "description": "Complete Software Engineering for CS/IT Students by KnowledgeGATE Sanchit Sir and Gate Smashers.",
      "thumbnailUrl": "https://img.youtube.com/vi/NlLM3sVF8wY/hqdefault.jpg",
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

  print('Starting course seed/update process...');

  for (final course in newCourses) {
    final title = course['title'] as String;
    final titleLower = title.toLowerCase().trim();

    // Check duplicate
    final isDup = existingTitles.any((e) => e.contains(titleLower) || titleLower.contains(e));
    if (isDup) {
      print('Course "$title" already exists or similar title found. Updating...');
    }

    final modules = (course['modules'] as List).map((m) {
      return {
        "mapValue": {
          "fields": {
            "id": {"stringValue": m['id']},
            "title": {"stringValue": m['title']},
            "youtubeVideoId": {"stringValue": m['youtubeVideoId']},
            "duration": {"stringValue": m['duration']},
            "notesReference": {"stringValue": ""},
            "importantQuestionsReference": {"stringValue": ""}
          }
        }
      };
    }).toList();

    final body = {
      "fields": {
        "title": {"stringValue": course['title']},
        "description": {"stringValue": course['description']},
        "thumbnailUrl": {"stringValue": course['thumbnailUrl']},
        "category": {"stringValue": course['category']},
        "level": {"stringValue": course['level']},
        "duration": {"stringValue": course['duration']},
        "youtubePlaylistUrl": {"stringValue": course['youtubePlaylistUrl']},
        "channelName": {"stringValue": course['channelName']},
        "isFeatured": {"booleanValue": course['isFeatured']},
        "order": {"integerValue": course['order'].toString()},
        "createdAt": {"timestampValue": DateTime.now().toUtc().toIso8601String()},
        "modules": {
          "arrayValue": {
            "values": modules
          }
        }
      }
    };

    final resp = await http.post(
      Uri.parse(baseUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      print('ADDED/UPDATED: $title');
    } else {
      print('Failed $title: ${resp.statusCode}');
    }
  }

  print('ALL 10 COURSES UPDATED & SEEDED SUCCESSFULLY!');
}
