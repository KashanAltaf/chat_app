import 'package:chat_app/modules/search/controller/search_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:get/get.dart';

class SearchScreen extends GetView<SearchingController>{

  static const String id = '/search';

  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Search'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
    );
  }

}