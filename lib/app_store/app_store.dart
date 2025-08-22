import 'package:shared_preferences/shared_preferences.dart';

class AppStore{

  setUserImage(String value)async{
    SharedPreferences sp = await SharedPreferences.getInstance();
    sp.setString('user_image', value);
  }
  Future<String>getUserImage()async{
    SharedPreferences sp = await SharedPreferences.getInstance();
    String? userImage = sp.getString('user_image');
    return userImage??"";  }

  setUserName(String value)async{
    SharedPreferences sp = await SharedPreferences.getInstance();
    sp.setString('user_name', value);
  }

  Future<String>getUserName()async{
    SharedPreferences sp = await SharedPreferences.getInstance();
    String? userName = sp.getString('user_name');
    return userName??"";
  }

  setUserToken(String value)async{
    SharedPreferences sp = await SharedPreferences.getInstance();
    sp.setString('user_token', value);
  }

  Future<String>getUserToken()async{
    SharedPreferences sp = await SharedPreferences.getInstance();
    String? userToken = sp.getString('user_token');
    return userToken??"";
  }

  removeToken()async{
    SharedPreferences sp = await SharedPreferences.getInstance();
    sp.remove('user_token');
  }
}