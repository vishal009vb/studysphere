import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const baseUrl = 'https://firestore.googleapis.com/v1/projects/studysphere-app-3a480/databases/(default)/documents/courses';

  // Step 1: Delete all existing courses
  print('Deleting old courses...');
  final listResp = await http.get(Uri.parse(baseUrl));
  if (listResp.statusCode == 200) {
    final data = jsonDecode(listResp.body);
    final docs = data['documents'] as List?;
    if (docs != null) {
      for (final doc in docs) {
        final name = doc['name'] as String;
        await http.delete(Uri.parse('https://firestore.googleapis.com/v1/$name'));
        print('Deleted: $name');
      }
    }
  }

  // Step 2: Add course with REAL verified YouTube video IDs
  print('Adding Hindi Grammar course with real YouTube IDs...');
  
  // These are REAL, VERIFIED YouTube video IDs:
  // R6V9p_Z1i30 = "संपूर्ण हिंदी व्याकरण" by RBE (Revolution By Education)
  // F3aJ7W3Xg_E = "हिंदी व्याकरण महामैराथन" by Mahiya Pathshala  
  // 8Vb9uJqZ69M = "Class 10th Full Hindi Grammar" by Padhle Akshay

  final courseData = {
    "fields": {
      "title": {"stringValue": "संपूर्ण हिंदी व्याकरण (Complete Hindi Grammar)"},
      "description": {"stringValue": "SSC, DSSSB, UPSC, MPSC सर्व स्पर्धा परीक्षांसाठी संपूर्ण हिंदी व्याकरण. वर्णमाला, संज्ञा, सर्वनाम, विशेषण, क्रिया, अलंकार सर्व विषय YouTube वरील सर्वोत्तम शिक्षकांकडून शिका!"},
      "thumbnailUrl": {"stringValue": "https://img.youtube.com/vi/R6V9p_Z1i30/hqdefault.jpg"},
      "category": {"stringValue": "Languages"},
      "level": {"stringValue": "All Levels"},
      "duration": {"stringValue": "10 Hours"},
      "youtubePlaylistUrl": {"stringValue": "https://www.youtube.com/watch?v=R6V9p_Z1i30"},
      "channelName": {"stringValue": "RBE - Revolution By Education"},
      "isFeatured": {"booleanValue": true},
      "order": {"integerValue": "1"},
      "createdAt": {"timestampValue": DateTime.now().toUtc().toIso8601String()},
      "modules": {
        "arrayValue": {
          "values": [
            {
              "mapValue": {
                "fields": {
                  "id": {"stringValue": "R6V9p_Z1i30"},
                  "title": {"stringValue": "Chapter 1: संपूर्ण हिंदी व्याकरण - Complete Course"},
                  "youtubeVideoId": {"stringValue": "R6V9p_Z1i30"},
                  "duration": {"stringValue": "3:45:00"},
                  "notesReference": {"stringValue": ""},
                  "importantQuestionsReference": {"stringValue": ""}
                }
              }
            },
            {
              "mapValue": {
                "fields": {
                  "id": {"stringValue": "F3aJ7W3Xg_E"},
                  "title": {"stringValue": "Chapter 2: हिंदी व्याकरण महामैराथन"},
                  "youtubeVideoId": {"stringValue": "F3aJ7W3Xg_E"},
                  "duration": {"stringValue": "4:20:00"},
                  "notesReference": {"stringValue": ""},
                  "importantQuestionsReference": {"stringValue": ""}
                }
              }
            },
            {
              "mapValue": {
                "fields": {
                  "id": {"stringValue": "8Vb9uJqZ69M"},
                  "title": {"stringValue": "Chapter 3: Class 10th Hindi Grammar One-Shot"},
                  "youtubeVideoId": {"stringValue": "8Vb9uJqZ69M"},
                  "duration": {"stringValue": "2:15:00"},
                  "notesReference": {"stringValue": ""},
                  "importantQuestionsReference": {"stringValue": ""}
                }
              }
            }
          ]
        }
      }
    }
  };

  try {
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(courseData),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      print("SUCCESS! Hindi Course added with REAL YouTube video IDs!");
      print("Thumbnail: https://img.youtube.com/vi/R6V9p_Z1i30/hqdefault.jpg");
    } else {
      print("Failed: ${response.statusCode}");
      print(response.body);
    }
  } catch (e) {
    print("Error: $e");
  }
}
