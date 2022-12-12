import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_d2go/flutter_d2go.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:auto_size_text/auto_size_text.dart';

List<CameraDescription> cameras = [];
String finalDesc = '';
String isEdible = '';
Color edibilityColor = Colors.green;
class WildPlants{
  String plantName;
  String plantDesc;
  String edibility;
  WildPlants(this.plantName, this.plantDesc, this.edibility);

}

List<WildPlants> wildPlants = [WildPlants('Asparagus', 'Wild asparagus can be found among the tall grasses and older growth from previous years. The stalks are thin and green with green or purple, coniferous-like crowns and similarly colored scales or leaves, growing along the stems. The stalks are firm and provide a crisp texture.', 'edible'),
                                WildPlants('Chickweed', 'Common chickweed grows erect to prostrate and sometimes is matlike. Stems are mostly forked and have a line of hairs down either side. Leaves are broadly egg shaped, have a pointy tip, and are mostly hairless or have hairy margins at the base. The leaves are spaced evenly and are opposite to one another along the stem.', 'edible'),
                                  WildPlants('Common Sow Thistle', 'An erect, hairless, branched annual or biennial herb about 1 m tall with a taproot and hollow stems which have a milky sap. The basal leaves are up to 30 cm long, form a rosette and are soft and lobed or toothed.', 'edible'),
                                    WildPlants('Peppergrass', 'The broad basal leaves differ from the narrow leaves on the flowering stalks and range from entire to deeply lobed. Small greenish or whitish four-petaled flowers are arranged in short spikes, and the seeds are usually borne in flat, round, dry fruits called silicles.', 'edible'),
                                      WildPlants('Wild Leak', 'A popular edible that grows in quality hardwood forests across the Midwest to the Northeast, and south to Virginia. The broad flat leaves with burgundy stems emerge in early spring from a bulb. Both the leaves and bulbs are edible and have a mild onion flavor.', 'edible'),
                                        WildPlants('broccoli', 'A fast-growing annual plant that grows 60–90 cm (24–35 inches) tall. Upright and branching with leathery leaves, broccoli bears dense green clusters of flower buds at the ends of the central axis and the branches.', 'edible')];

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint('Error: ${e.code}, Message: ${e.description}');
  }
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<RecognitionModel>? _recognitions;
  File? _selectedImage;
  final List<String> _imageList = ['test1.png', 'test2.jpeg', 'test3.png'];
  int _index = 0;
  int? _imageWidth;
  int? _imageHeight;
  final ImagePicker _picker = ImagePicker();

  CameraController? controller;
  bool _isDetecting = false;
  bool _isLiveModeOn = false;

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> live() async {
    controller = CameraController(
      cameras[0],
      ResolutionPreset.high,
    );
    await controller!.initialize().then(
      (_) {
        if (!mounted) {
          return;
        }
        setState(() {});
      },
    );
    await controller!.startImageStream(
      (CameraImage cameraImage) async {
        if (_isDetecting) return;

        _isDetecting = true;

        await FlutterD2go.getStreamImagePrediction(
          imageBytesList:
              cameraImage.planes.map((plane) => plane.bytes).toList(),
          width: cameraImage.width,
          height: cameraImage.height,
          minScore: 0.5,
          rotation: 90,
        ).then(
          (predictions) {
            List<RecognitionModel>? recognitions;
            if (predictions.isNotEmpty) {
              recognitions = predictions.map(
                (e) {
                  return RecognitionModel(
                      Rectangle(
                        e['rect']['left'],
                        e['rect']['top'],
                        e['rect']['right'],
                        e['rect']['bottom'],
                      ),
                      e['mask'],
                      e['keypoints'] != null
                          ? (e['keypoints'] as List)
                          .map((k) => Keypoint(k[0], k[1]))
                          .toList()
                          : null,
                      e['confidenceInClass'],
                      e['detectedClass']);
                },
              ).toList();
            }
            setState(
              () {
                // With android, the inference result of the camera streaming image is tilted 90 degrees,
                // so the vertical and horizontal directions are reversed.
                _imageWidth = cameraImage.height;
                _imageHeight = cameraImage.width;
                _recognitions = recognitions;
              },
            );
          },
        ).whenComplete(
          () => Future.delayed(
            const Duration(
              milliseconds: 100,
            ),
            () {
              setState(() => _isDetecting = false);
            },
          ),
        );
      },
    );
  }




  Future loadModel() async {
    String modelPath = 'assets/models/josh_faster_new.ptl';
    String labelPath = 'assets/models/classes_new.txt';
    try {
      await FlutterD2go.loadModel(
        modelPath: modelPath,
        labelPath: labelPath,
      );
      setState(() {});
    } on PlatformException {
      debugPrint('Load model or label file failed.');
    }
  }

  Future setText(RecognitionModel recognizedModel)async{

    return 'hello';
  }

  Future detect() async {
    final image = _selectedImage ??
        await getImageFileFromAssets('assets/images/${_imageList[_index]}');
    final decodedImage = await decodeImageFromList(image.readAsBytesSync());
    final predictions = await FlutterD2go.getImagePrediction(
      image: image,
      minScore: 0.06,
    );
    List<RecognitionModel>? recognitions;
    if (predictions.isNotEmpty) {
      recognitions = predictions.map(
        (e) {
          return RecognitionModel(
              Rectangle(
                e['rect']['left'],
                e['rect']['top'],
                e['rect']['right'],
                e['rect']['bottom'],
              ),
              e['mask'],
              e['keypoints'] != null
                  ? (e['keypoints'] as List)
                      .map((k) => Keypoint(k[0], k[1]))
                      .toList()
                  : null,
              e['confidenceInClass'],
              e['detectedClass']);
        },
      ).toList();
    }

    setState(
      () {
        _imageWidth = decodedImage.width;
        _imageHeight = decodedImage.height;
        _recognitions = recognitions;
      },
    );



  }

  Future<File> getImageFileFromAssets(String path) async {
    final byteData = await rootBundle.load(path);
    final fileName = path.split('/').last;
    final file = File('${(await getTemporaryDirectory()).path}/$fileName');
    await file.writeAsBytes(byteData.buffer
        .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));

    return file;
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width/2;
    List<Widget> stackChildren = [];
    stackChildren.add(
      Positioned(
        top: 10.0,
        left: 90.0,
        width: screenWidth,
        child: _selectedImage == null
            ? Image.asset(
                'assets/images/${_imageList[_index]}',
              )
            : Image.file(_selectedImage!),
      ),
    );

    if (_isLiveModeOn) {
      stackChildren.add(
        Positioned(
          top: 0.0,
          left: 0.0,
          width: screenWidth,
          child: CameraPreview(controller!),
        ),
      );
    }

    if (_recognitions != null) {
      final aspectRatio = _imageHeight! / _imageWidth! * screenWidth;
      final widthScale = screenWidth / _imageWidth!;
      final heightScale = aspectRatio / _imageHeight!;

      if (_recognitions!.first.mask != null) {
        stackChildren.addAll(_recognitions!.map(
          (recognition) {
            return RenderSegments(
              imageWidthScale: widthScale,
              imageHeightScale: heightScale,
              recognition: recognition,
            );
          },
        ).toList());
      }

      if (_recognitions!.first.keypoints != null) {
          RecognitionModel? recognition = _recognitions?.first;
          List<Widget> keypointChildren = [];
            if(recognition != null) {
              for (Keypoint keypoint in recognition.keypoints!) {
                keypointChildren.add(
                  RenderKeypoints(
                    keypoint: keypoint,
                    imageWidthScale: widthScale,
                    imageHeightScale: heightScale,
                  ),
                );

                stackChildren.addAll(keypointChildren);
              }
            }
      }

      stackChildren.addAll(_recognitions!.map(
        (recognition) {
          return RenderBoxes(
            imageWidthScale: widthScale,
            imageHeightScale: heightScale,
            recognition: recognition,
          );
        },
      ).toList());
    }
    int indexChecker = 0;

        if(wildPlants.indexWhere((plant) => plant.plantName == '${_recognitions?.first.detectedClass!.toString()}') != -1){
          finalDesc = wildPlants[wildPlants.indexWhere((plant) => plant.plantName == '${_recognitions?.first.detectedClass!.toString()}')].plantDesc;
          isEdible = wildPlants[wildPlants.indexWhere((plant) => plant.plantName == '${_recognitions?.first.detectedClass!.toString()}')].edibility;
          edibilityColor = Colors.green;
        }else{
          finalDesc = 'No Class Description Detected Found!';
          isEdible = 'Undetermined';
          edibilityColor = Colors.red;
        }

    return Scaffold(
      appBar: AppBar(
        title: const Text('EXO'),
        backgroundColor: Colors.green,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 0),

          Expanded(
            child: Stack(
              children: stackChildren,
            ),
          ),

          const SizedBox(height: 0),
           SizedBox(
            width: 250.0,
            height: 25,
            child: AutoSizeText(
              '${_recognitions?.first.detectedClass!.toString()}',
              style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold, color: Colors.green),
              minFontSize: 15,

              textAlign: TextAlign.center,

            ),
          ),
          SizedBox(
            width: 100,
            height: 20,
            child: AutoSizeText(
              isEdible,
              style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold, color: Colors.black, backgroundColor: edibilityColor),
              minFontSize: 12,
              textAlign: TextAlign.center,

            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 250.0,
            height: 70.0,
            child: AutoSizeText(
              finalDesc,
              style: TextStyle(fontSize: 12.0, color: Colors.green),
              minFontSize: 5,
              textAlign: TextAlign.justify,

            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,

              children: [
                SizedBox(
                  height: 75.0 ,
                  width: 75.0 ,
                  child: FloatingActionButton(
                    onPressed: () async {
                      final XFile? pickedFile =
                      await _picker.pickImage(source: ImageSource.gallery);
                      if (pickedFile == null) return;
                      setState(
                            () {
                          _recognitions = null;
                          _selectedImage = File(pickedFile.path);
                        },
                      );
                    },
                    child: const Icon(

                        Icons.photo

                    ),backgroundColor: Colors.green,

                  ),
                ),
                SizedBox(
                  height: 100.0 ,
                  width: 100.0 ,
                  child: FloatingActionButton(
                    onPressed: !_isLiveModeOn ? detect : null,
                    child: const Icon(

                        Icons.eco

                    ),backgroundColor: Colors.green,

                  ),
                ),
                SizedBox(
                  height: 75.0 ,
                  width: 75.0 ,
                  child: FloatingActionButton(
                    onPressed: () async {
                      final XFile? pickedFile =
                      await _picker.pickImage(source: ImageSource.camera);
                      if (pickedFile == null) return;
                      setState(
                            () {
                          _recognitions = null;
                          _selectedImage = File(pickedFile.path);
                        },
                      );
                    },
                    child: const Icon(
                        Icons.add_a_photo

                    ),backgroundColor: Colors.green,

                  ),
                ),



              ],
            ),
          ),
        ],
      ),

    );
  }
}

class MyButton extends StatelessWidget {
  const MyButton({Key? key, required this.onPressed, required this.text})
      : super(key: key);

  final VoidCallback? onPressed;
  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 42,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 12,
          ),
        ),
        style: ElevatedButton.styleFrom(
          primary: Colors.grey[300],
          elevation: 0,
        ),
      ),
    );
  }
}

class RenderBoxes extends StatelessWidget {
  const RenderBoxes({
    Key? key,
    required this.recognition,
    required this.imageWidthScale,
    required this.imageHeightScale,
  }) : super(key: key);

  final RecognitionModel recognition;
  final double imageWidthScale;
  final double imageHeightScale;

  @override
  Widget build(BuildContext context) {
    final left = recognition.rect.left* imageWidthScale + 90;
    final top = recognition.rect.top * imageHeightScale + 10;
    final right = recognition.rect.right * imageWidthScale + 90;
    final bottom = recognition.rect.bottom * imageHeightScale + 10;
    return Positioned(
      left: left,
      top: top,
      width: right - left,
      height: bottom - top,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(8.0)),
          border: Border.all(
            color: Colors.red,
            width: 2,
          ),
        ),
        child: Text(
          "${recognition.detectedClass} ${(recognition.confidenceInClass * 100).toStringAsFixed(0)}%",
          style: TextStyle(
            background: Paint()..color = Colors.greenAccent,
            color: Colors.brown,
            fontSize: 15.0,
          ),
        ),
      ),
    );
  }
}

class RenderSegments extends StatelessWidget {
  const RenderSegments({
    Key? key,
    required this.recognition,
    required this.imageWidthScale,
    required this.imageHeightScale,
  }) : super(key: key);

  final RecognitionModel recognition;
  final double imageWidthScale;
  final double imageHeightScale;

  @override
  Widget build(BuildContext context) {
    final left = recognition.rect.left * imageWidthScale + 90;
    final top = recognition.rect.top * imageHeightScale + 10;
    final right = recognition.rect.right * imageWidthScale + 90;
    final bottom = recognition.rect.bottom  * imageHeightScale + 10;
    final mask = recognition.mask!;
    return Positioned(
      left: left,
      top: top,
      width: right - left,
      height: bottom - top,
      child: Image.memory(
        mask,
        fit: BoxFit.fill,
      ),
    );
  }
}

class RenderKeypoints extends StatelessWidget {
  const RenderKeypoints({
    Key? key,
    required this.keypoint,
    required this.imageWidthScale,
    required this.imageHeightScale,
  }) : super(key: key);

  final Keypoint keypoint;
  final double imageWidthScale;
  final double imageHeightScale;

  @override
  Widget build(BuildContext context) {
    final x = keypoint.x * imageWidthScale + 90;
    final y = keypoint.y * imageHeightScale + 10;
    return Positioned(
      left: x,
      top: y,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class RecognitionModel {
  RecognitionModel(
    this.rect,
    this.mask,
    this.keypoints,
    this.confidenceInClass,
    this.detectedClass,
  );
  Rectangle rect;
  Uint8List? mask;
  List<Keypoint>? keypoints;
  double confidenceInClass;
  String detectedClass;
}

class Rectangle {
  Rectangle(this.left, this.top, this.right, this.bottom);
  double left;
  double top;
  double right;
  double bottom;
}

class Keypoint {
  Keypoint(this.x, this.y);
  double x;
  double y;
}
