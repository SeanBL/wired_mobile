import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wired_mobile/pages/policy.dart';
import '.././utils/functions.dart';
import 'package:archive/archive_io.dart';
import '../utils/custom_app_bar.dart';
import '../utils/custom_nav_bar.dart';
import '../utils/side_nav_bar.dart';
import 'home_page.dart';
import 'module_library.dart';
import 'module_info.dart';

class ModuleByAlphabet extends StatefulWidget {
  final String letter;

  ModuleByAlphabet({required this.letter});

  @override
  _ModuleByAlphabetState createState() => _ModuleByAlphabetState();
}

class Modules {
  String? name;
  String? description;
  //String? version;
  String? downloadLink;
  //String? packageSize;
  String? letters;
  bool? isDownloadable;
  Modules? redirectedModule;


  Modules({
    this.name,
    this.description,
    //this.version,
    this.downloadLink,
    //this.packageSize,
    this.letters,
    this.isDownloadable,
    this.redirectedModule,
  });

  Modules.fromJson(Map<String, dynamic> json)
    : name = json['name'] as String,
      description = json['description'] as String,
      //version = json['version'] as String,
      downloadLink = json['downloadLink'] as String,
      //packageSize = json['packageSize'] as String,
      letters = json['letters'] as String,
      isDownloadable = json['is_downloadable'] as bool,
        redirectedModule = json['redirectedModule'] != null
            ? Modules.fromJson(json['redirectedModule'])
            : null;

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    //'version': version,
    'downloadLink': downloadLink,
    //'packageSize': packageSize,
    'letters': letters,
    'is_downloadable': isDownloadable,
    'redirectedModule': redirectedModule?.toJson(),
  };
}

class _ModuleByAlphabetState extends State<ModuleByAlphabet> {
  late Future<List<Modules>> futureModules;
  late List<Modules> moduleData = [];

  // Get the Module Data
  Future<List<Modules>> getModules() async {
    try {
      final response = await http.get(Uri.parse(
          'http://10.0.2.2:3000/modules'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<Modules> allModules = data.map<Modules>((e) => Modules.fromJson(e))
            .toList();

        // Filter modules by the letter
        moduleData = allModules.where((module) => module.letters?.contains(
            widget.letter) ?? false).toList();

        // change to lower case and Sort modules by name
        moduleData.sort((a, b) =>
            a.name!.toLowerCase().compareTo(b.name!.toLowerCase()));

        debugPrint("Module Data: ${moduleData.length}");
        debugPrint("Module Data: ${moduleData[0].isDownloadable}, ");
        return moduleData;
      } else {
        debugPrint("Failed to load modules");
      }
      return moduleData;
    } catch (e) {
      debugPrint("$e");
    }
    return moduleData;
  }

  // Get Permissions
  Future<bool> checkAndRequestStoragePermission() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    return status.isGranted;
  }

  // Download the Module
  Future<void> downloadModule(String url, String fileName) async {
    bool hasPermission = await checkAndRequestStoragePermission();
    print("Has Permission: $hasPermission");
    if (true) {
      final directory = await getExternalStorageDirectory(); // Get the External Storage Directory (Android)
      final filePath = '${directory!.path}/$fileName';
      final file = File(filePath);

      try {
        final response = await http.get(Uri.parse(url));
        await file.writeAsBytes(response.bodyBytes);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded $fileName')),
        );
        print('Directory: ${directory.path}');
        print('File Path: $filePath');

        // Unzip the downloaded file
        final bytes = file.readAsBytesSync();
        final archive = ZipDecoder().decodeBytes(bytes);

        for (var file in archive) {
          final filename = file.name;
          final filePath = '${directory.path}/$filename';
          print('Processing file: $filename at path: $filePath');

          if (file.isFile) {
            final data = file.content as List<int>;
            File(filePath)
              ..createSync(recursive: true)
              ..writeAsBytesSync(data);
          } else {
            Directory(filePath).createSync(recursive: true);
            print('Directory created: $filePath');
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unzipped $fileName')),
        );
        print('Unzipped to: ${directory.path}');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading $fileName')),
        );
      }
    } else {
      openAppSettings();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Permission denied')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    futureModules = getModules();
  }

  @override
  Widget build(BuildContext context) {
    var screenWidth = MediaQuery.of(context).size.width;
    var screenHeight = MediaQuery.of(context).size.height;
    bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      body: Row(
        children: [
          // Conditionally show the side navigation bar in landscape mode
          if (isLandscape)
            CustomSideNavBar(
              onHomeTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => MyHomePage()));
              },
              onLibraryTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => ModuleLibrary()));
              },
              onHelpTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => const Policy()));
              },
            ),

          // Main content area (expanded to fill remaining space)
          Expanded(
            child: Stack(
              children: <Widget>[
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFFFF0DC),
                        Color(0xFFF9EBD9),
                        Color(0xFFFFC888),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Center(
                      child: isLandscape ? _buildLandscapeLayout(
                          screenWidth, screenHeight) : _buildPortraitLayout(
                          screenWidth, screenHeight),
                    ),
                  ),
                ),
                // Conditionally show the bottom navigation bar in portrait mode
                if (!isLandscape)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: CustomBottomNavBar(
                      onHomeTap: () {
                        Navigator.push(context, MaterialPageRoute(
                              builder: (context) => MyHomePage()),
                        );
                      },
                      onLibraryTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (
                            context) => ModuleLibrary()));
                      },
                      onHelpTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (
                            context) => const Policy()));
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortraitLayout(screenWidth, screenHeight) {
    return Column(
      children: [
        //Imported from utils/custom_app_bar.dart
        CustomAppBar(
          onBackPressed: () {
            Navigator.pop(context);
          },
        ),
        Container(
          child: Column(
            children: [
              Text(
                "Search by",
                style: TextStyle(
                  fontSize: screenWidth * 0.1,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0070C0),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Alphabet: ",
                    style: TextStyle(
                      fontSize: screenWidth * 0.1,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0070C0),
                    ),
                  ),
                  Text(
                    widget.letter,
                    style: TextStyle(
                      fontSize: screenWidth * 0.1,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF548235),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Stack(
          children: [
            Container(
              // height: 650,
              // width: 400,
              height: screenHeight * 0.63,
              width: screenWidth * 1.0,
              decoration: BoxDecoration(
                color: Colors.transparent,
              ),
              child: FutureBuilder<List<Modules>>(
                future: futureModules,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return ListView.builder(
                      itemCount: moduleData.length + 1,
                      // Increase the item count by 1 to account for the SizedBox as the last item
                      itemBuilder: (context, index) {
                        if (index == moduleData.length) {
                          // This is the last item (the SizedBox or Container)
                          return SizedBox(
                            height: screenHeight * 0.21,
                          );
                        }
                        final module = moduleData[index];
                        final moduleName = module.name ?? "Unknown Module";
                        debugPrint("Module Name: ${moduleName}");
                        final downloadLink = module.downloadLink ??
                            "No Link available";
                        final moduleDescription = module.description ??
                            "No Description available";

                        if (module.redirectedModule != null) {
                          return Column(
                            children: [
                              Center(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      "$moduleName see",
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: screenWidth * 0.05,
                                        fontFamilyFallback: [
                                          'NotoSans',
                                          'NotoSerif',
                                          'Roboto',
                                          'sans-serif',
                                        ],
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    // Text(
                                    //   'see',
                                    //   style: TextStyle(
                                    //     color: Colors.black,
                                    //     fontSize: screenWidth * 0.0567,
                                    //     fontFamilyFallback: [
                                    //       'NotoSans',
                                    //       'NotoSerif',
                                    //       'Roboto',
                                    //       'sans-serif',
                                    //     ],
                                    //     fontWeight: FontWeight.w500,
                                    //   ),
                                    //   textAlign: TextAlign.center,
                                    // ),
                                    GestureDetector(
                                      onTap: () async {
                                        if (module.redirectedModule!.downloadLink != null &&
                                            module.redirectedModule!.downloadLink!.isNotEmpty) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ModuleInfo(
                                                moduleName: module.redirectedModule!.name!,
                                                moduleDescription: module.redirectedModule!.description ?? "No Description available",
                                                downloadLink: module.redirectedModule!.downloadLink!,
                                              ),
                                            ),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('No download link found for ${module.redirectedModule!.name}')),
                                          );
                                        }
                                      },
                                      child: Text(
                                        module.redirectedModule!.name!,
                                        style: TextStyle(
                                          color: Color(0xFF0070C0), // Redirected module name in blue
                                          fontSize: screenWidth * 0.055,
                                          fontFamilyFallback: [
                                            'NotoSans',
                                            'NotoSerif',
                                            'Roboto',
                                            'sans-serif',
                                          ],
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(
                                color: Colors.grey,
                                height: 1,
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              InkWell(
                                onTap: () async {
                                  if (module.downloadLink != null && module.downloadLink!.isNotEmpty) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ModuleInfo(
                                          moduleName: moduleName,
                                          moduleDescription: moduleDescription,
                                          downloadLink: downloadLink,
                                        ),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('No download link found for ${module.name}')),
                                    );
                                  }
                                },
                                child: Center(
                                  child: Text(
                                    moduleName,
                                    style: TextStyle(
                                      color: Color(0xFF0070C0),
                                      fontSize: screenWidth * 0.055,
                                      fontFamilyFallback: [
                                        'NotoSans',
                                        'NotoSerif',
                                        'Roboto',
                                        'sans-serif',
                                      ],
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              const Divider(
                                color: Colors.grey,
                                height: 1,
                              ),
                            ],
                          );
                        }
                      },
                    );
                  } else if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  } else {
                    return const CircularProgressIndicator();
                  }
                },
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  //height: 150,
                    height: screenHeight * 0.2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.0, 1.0],
                        colors: [
                          // Colors.transparent,
                          // Color(0xFFFFF0DC),
                          //Theme.of(context).scaffoldBackgroundColor.withOpacity(0.0),
                          Color(0xFFFED09A).withOpacity(0.0),
                          Color(0xFFFED09A),
                        ],
                      ),
                    )
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout(screenWidth, screenHeight) {
    var baseSize = MediaQuery.of(context).size.shortestSide;
    return Column(
      children: [
        //Imported from utils/custom_app_bar.dart
        CustomAppBar(
          onBackPressed: () {
            Navigator.pop(context);
          },
        ),
        Container(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Search by ",
                style: TextStyle(
                  fontSize: baseSize * (isTablet(context) ? 0.09 : 0.1),
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF0070C0),
                ),
              ),
              Text(
                "Alphabet: ",
                style: TextStyle(
                  fontSize: baseSize * (isTablet(context) ? 0.09 : 0.1),
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF0070C0),
                ),
              ),
              Text(
                widget.letter,
                style: TextStyle(
                  fontSize: baseSize * (isTablet(context) ? 0.09 : 0.1),
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF548235),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Stack(
          children: [
            Container(
              // height: 650,
              // width: 400,
              height: baseSize * (isTablet(context) ? 0.68 : 0.63),
              width: baseSize * (isTablet(context) ? 1.25 : 1.0),
              decoration: BoxDecoration(
                color: Colors.transparent,
              ),
              child: FutureBuilder<List<Modules>>(
                future: futureModules,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return ListView.builder(
                      itemCount: moduleData.length + 1,
                      // Increase the item count by 1 to account for the SizedBox as the last item
                      itemBuilder: (context, index) {
                        if (index == moduleData.length) {
                          // This is the last item (the SizedBox or Container)
                          return SizedBox(
                            height: screenHeight * 0.21,
                          );
                        }
                        final module = moduleData[index];
                        final moduleName = module.name ?? "Unknown Module";
                        final downloadLink = module.downloadLink ??
                            "No Link available";
                        final moduleDescription = module.description ??
                            "No Description available";
                        return Column(
                          children: [
                            InkWell(
                              onTap: () async {
                                //print("Downloading ${moduleData[index].downloadLink}");
                                if (moduleData[index].downloadLink != null) {
                                  // String fileName = "$moduleName.zip";
                                  // await downloadModule(downloadLink, fileName);
                                  Navigator.push(context, MaterialPageRoute(
                                      builder: (context) => ModuleInfo(
                                          moduleName: moduleName,
                                          moduleDescription: moduleDescription,
                                          downloadLink: downloadLink)));
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(
                                        'No download link found for ${moduleData[index]
                                            .name}')),
                                  );
                                }
                              },
                              child: Center(
                                child: ListTile(
                                  title: Text(
                                    moduleData[index].name!,
                                    style: TextStyle(
                                      //fontSize: 24,
                                      fontSize: baseSize * (isTablet(context) ? 0.0667 : 0.0667),
                                      fontFamilyFallback: [
                                        'NotoSans',
                                        'NotoSerif',
                                        'Roboto',
                                        'sans-serif'
                                      ],
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF0070C0),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                            // const Divider(
                            //   color: Colors.grey,
                            //   height: 1,
                            // ),
                            Container(
                                height: 1,
                                width: 500,
                                color: Colors.grey,

                            ),
                          ],
                        );
                      },
                    );
                  } else if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  } else {
                    return const CircularProgressIndicator();
                  }
                },
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  //height: 150,
                    height: baseSize * (isTablet(context) ? 0.28 : 0.2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.0, 1.0],
                        colors: [
                          // Colors.transparent,
                          // Color(0xFFFFF0DC),
                          //Theme.of(context).scaffoldBackgroundColor.withOpacity(0.0),
                          Color(0xFFFED09A).withOpacity(0.0),
                          Color(0xFFFED09A),
                        ],
                      ),
                    )
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
