import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter/foundation.dart';

Future<void> cleanUpCourses() async {
  final db = FirebaseFirestore.instance;
  
  // Find the Hindi course and delete it
  final snapshot = await db.collection('courses')
    .where('title', isEqualTo: 'संपूर्ण हिंदी व्याकरण (Complete Hindi Grammar)')
    .get();
    
  for (var doc in snapshot.docs) {
    debugPrint('Deleting course: ${doc.id}');
    await doc.reference.delete();
  }
}

Future<void> fixAllPlaylists() async {
  final db = FirebaseFirestore.instance;
  final snapshot = await db.collection('courses').get();
  final yt = YoutubeExplode();
  
  for (var doc in snapshot.docs) {
    final data = doc.data();
    final String? playlistUrl = data['youtubePlaylistUrl'];
    
    if (playlistUrl != null && playlistUrl.contains('playlist?list=')) {
      final listId = playlistUrl.split('playlist?list=')[1].split('&').first;
      try {
        var videoStream = yt.playlists.getVideos(listId);
        int index = 1;
        List<Map<String, dynamic>> modules = [];
        
        await for (var video in videoStream) {
          modules.add({
            'id': '${doc.id}_vid_$index',
            'title': video.title,
            'youtubeVideoId': video.id.value,
            'duration': video.duration?.inMinutes.toString() ?? '0',
          });
          index++;
        }
        
        if (modules.isNotEmpty) {
          await doc.reference.update({
            'modules': modules,
            'totalVideos': modules.length,
          });
          debugPrint('Fixed playlist for ${data['title']} - Added ${modules.length} videos');
        }
      } catch (e) {
        debugPrint('Error fixing playlist for ${data['title']}: $e');
      }
    }
  }
  yt.close();
}
