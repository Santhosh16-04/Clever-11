import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ConnectivityUtils {
  static Future<bool> isConnected() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  static Future<void> checkConnectionAndExecute(
    BuildContext context,
    VoidCallback onConnected, {
    String? customMessage,
    bool showToast = true,
  }) async {
    if (await isConnected()) {
      onConnected();
    } else {
      if (showToast) {
        _showNoInternetMessage(context, customMessage);
      }
    }
  }

  static void _showNoInternetMessage(BuildContext context, String? customMessage) {
    final message = customMessage ?? 'Please check your internet connection';
    
    // Show toast message
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.CENTER,
      backgroundColor: Colors.red[700],
      textColor: Colors.white,
      fontSize: 16.0,
    );

    // Also show a snackbar for better visibility
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[700],
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  static Future<bool> showConnectionDialog(BuildContext context) async {
    if (await isConnected()) {
      return true;
    }

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text('No Internet Connection'),
            ],
          ),
          content: Text(
            'Please check your internet connection and try again.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(false);
                // Try to check connection again
                if (await isConnected()) {
                  Navigator.of(context).pop(true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Retry',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        );
      },
    ) ?? false;
  }

  static Widget wrapWithConnectivityCheck({
    required Widget child,
    required VoidCallback onTap,
    String? noInternetMessage,
    bool showDialog = false,
  }) {
    return Builder(
      builder: (context) {
        return GestureDetector(
          onTap: () async {
            if (showDialog) {
              final hasConnection = await showConnectionDialog(context);
              if (hasConnection) {
                onTap();
              }
            } else {
              ConnectivityUtils.checkConnectionAndExecute(
                context,
                onTap,
                customMessage: noInternetMessage,
              );
            }
          },
          child: child,
        );
      },
    );
  }
}
