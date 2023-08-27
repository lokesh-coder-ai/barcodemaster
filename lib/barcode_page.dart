import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:intl/intl.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver/gallery_saver.dart';

class BarcodePage extends StatefulWidget {
  static const String id = "barcode";
  @override
  State<BarcodePage> createState() => _BarcodePageState();
}

class _BarcodePageState extends State<BarcodePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  GlobalKey _screenShotKey = GlobalKey();
  String itemNumber = '';
  String itemName = " ";
  late DateTime manufacturedDate;
  late DateTime expiryDate;
  bool isButtonClicked = false;
  String generatedBarcode = '';
  String scannedBarcodeData = '';
  String scannedData = '';

  Future<File> _captureAndSaveScreenshot() async {
    try {
      RenderRepaintBoundary boundary = _screenShotKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;

      if (boundary.debugNeedsPaint) {
        await Future.delayed(const Duration(milliseconds: 20));
      }

      // ignore: dead_code

      ui.Image image = await boundary.toImage(pixelRatio: 10.0);

      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List? pngBytes = byteData?.buffer.asUint8List();
      var capturedScreenshot = pngBytes;

      final tempPath = (await getTemporaryDirectory()).path;
      final path = '$tempPath/qr.png';
      File imgFile = File(path);
      await imgFile.writeAsBytes(pngBytes as List<int>);

      return imgFile; // Return the File after it's been saved
    } catch (e) {
      print("Error capturing and saving screenshot: $e");
      throw e; // Rethrow the error to be caught outside
    }
  }

  void save() async {
    try {
      File savedFile = await _captureAndSaveScreenshot();
      bool? saved = await GallerySaver.saveImage(savedFile.path);
      print(saved);
    } catch (error) {
      print("Error saving screenshot: $error");
    }
  }

  Future<void> _showSuccessDialog() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Success'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Data stored successfully!'),
              RepaintBoundary(
                key: _screenShotKey,
                child: BarcodeWidget(
                  barcode: Barcode.code128(),
                  data: generatedBarcode,
                  height: 100,
                  width: 300,
                  drawText: false,
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: save,
                child: Text("Capture and Save Screenshot"),
              ),
            ],
          ),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _storeBarcodeData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final barcodeData = {
        'item Number': int.parse(itemNumber),
        'item Name': itemName,
        'manufacturedDate': manufacturedDate,
        'expiryDate': expiryDate,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('users')
          .doc(user.email)
          .collection('barcodes')
          .doc(itemNumber + itemName.toLowerCase())
          .set(barcodeData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: null,
        actions: <Widget>[
          IconButton(
              icon: Icon(Icons.close),
              onPressed: () {
                _auth.signOut();
                Navigator.pop(context);
              }),
        ],
        title: Text('Barcode generator and store'),
        backgroundColor: Colors.lightBlueAccent,
      ),
      body: ListView(
        padding: EdgeInsets.all(16.0),
        children: <Widget>[
          TextFormField(
            onChanged: (value) {
              setState(() {
                itemNumber = value;
              });
            },
            decoration: InputDecoration(
              labelText: 'Item Number',
            ),
          ),
          TextFormField(
            onChanged: (value) {
              setState(() {
                itemName = value;
              });
            },
            decoration: InputDecoration(
              labelText: 'Item Name',
            ),
          ),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: () async {
              final selectedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2101),
              );
              if (selectedDate != null) {
                setState(() {
                  manufacturedDate = selectedDate;
                });
              }
            },
            child: Text('Select Manufactured Date'),
          ),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: () async {
              final selectedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2101),
              );
              if (selectedDate != null) {
                setState(() {
                  expiryDate = selectedDate;
                });
              }
            },
            child: Text('Select Expiry Date'),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              if (itemNumber.isNotEmpty &&
                  itemName.isNotEmpty &&
                  manufacturedDate != null &&
                  expiryDate != null) {
                await _storeBarcodeData();
                generatedBarcode = itemNumber + itemName.toLowerCase();
                await _showSuccessDialog();
                setState(() {
                  itemNumber = '';
                  itemName = '';
                  var _manufacturedDate = null;
                  manufacturedDate = _manufacturedDate;
                  var _expiryDate = null;
                  expiryDate = _expiryDate;
                  // generated bar code = ''
                  generatedBarcode = "";
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please fill in all fields')),
                );
              }
            },
            child: Text('Generate Barcode and Store'),
          ),
          SizedBox(height: 10),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              final scannedData = await FlutterBarcodeScanner.scanBarcode(
                '#FF0000',
                'Cancel',
                true,
                ScanMode.DEFAULT,
              );

              if (scannedData != '-1') {
                setState(() {
                  this.scannedData = scannedData;
                });

                final user = _auth.currentUser;
                if (user != null) {
                  final barcodeDoc = await _firestore
                      .collection('users')
                      .doc(user.email)
                      .collection('barcodes')
                      .doc(scannedData)
                      .get();

                  if (barcodeDoc.exists) {
                    final docData = barcodeDoc.data() as Map<String, dynamic>;
                    final manufacturedDate =
                        docData['manufacturedDate'].toDate();
                    final expiryDate = docData['expiryDate'].toDate();
                    final dateFormat = DateFormat('MMM d, yyyy');

                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text('Scanned Barcode Data'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Bar code Number: $scannedData'),
                              Text('Item Number: ${docData['item Number']}'),
                              Text('Item Name: ${docData['item Name']}'),
                              Text(
                                'Manufactured Date: ${manufacturedDate != null ? dateFormat.format(manufacturedDate) : "N/A"}',
                              ),
                              Text(
                                'Expiry Date: ${expiryDate != null ? dateFormat.format(expiryDate) : "N/A"}',
                              ),
                            ],
                          ),
                          actions: <Widget>[
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text('OK'),
                            ),
                          ],
                        );
                      },
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Barcode not found')),
                    );
                  }
                }
              }
            },
            child: Text('Scan Barcode'),
          ),
          // SizedBox(height: 20),
          // if (scannedData.isNotEmpty) DisplayScannedData(data: scannedData)
        ],
      ),
    );
  }
}

class DisplayScannedData extends StatelessWidget {
  final String data;

  const DisplayScannedData({required this.data});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.email)
          .collection('barcodes')
          .doc(data)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (snapshot.hasData && snapshot.data != null) {
          final docData = snapshot.data!.data()!;
          final manufacturedDate = docData['manufacturedDate'].toDate();
          final expiryDate = docData['expiryDate'].toDate();
          final dateFormat = DateFormat('MMM d, yyyy');

          return Column(
            children: [
              Text('Bar code Number: $data'),
              Text('Item Number: ${docData['item Number']}'),
              Text('Item Name: ${docData['item Name']}'),
              Text(
                'Manufactured Date: ${manufacturedDate != null ? dateFormat.format(manufacturedDate) : "N/A"}',
              ),
              Text(
                'Expiry Date: ${expiryDate != null ? dateFormat.format(expiryDate) : "N/A"}',
              )
            ],
          );
        }

        return Text('Barcode not found');
      },
    );
  }
}
