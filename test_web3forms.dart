import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  var request = http.MultipartRequest('POST', Uri.parse('https://catbox.moe/user/api.php'));
  request.fields['reqtype'] = 'fileupload';
  request.files.add(
    http.MultipartFile.fromBytes(
      'fileToUpload', 
      [0, 1, 2, 3], // Dummy data
      filename: 'test.jpg'
    )
  );

  var streamedResponse = await request.send();
  var response = await http.Response.fromStream(streamedResponse);
  
  print('Status code: ${response.statusCode}');
  print('Body: ${response.body}');
}
