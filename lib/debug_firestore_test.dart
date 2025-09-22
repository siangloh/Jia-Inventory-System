// Debug script to test Firestore connection and data
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreDebugTest {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> testPurchaseOrders() async {
    print('🔍 [DEBUG] Testing Firestore connection...');
    
    try {
      // Test basic connection
      await _firestore.collection('test').doc('test').get();
      print('✅ [DEBUG] Firestore connection successful');
      
      // Test purchase orders collection
      print('🔍 [DEBUG] Testing purchaseOrder collection...');
      final QuerySnapshot snapshot = await _firestore
          .collection('purchaseOrder')
          .limit(5)
          .get();
      
      print('🔍 [DEBUG] Found ${snapshot.docs.length} documents in purchaseOrder collection');
      
      if (snapshot.docs.isEmpty) {
        print('❌ [DEBUG] No documents found in purchaseOrder collection');
        print('🔍 [DEBUG] Collection exists but is empty');
        
        // Try to check if collection exists by attempting to add a test document
        try {
          await _firestore.collection('purchaseOrder').doc('test').set({'test': true});
          await _firestore.collection('purchaseOrder').doc('test').delete();
          print('✅ [DEBUG] purchaseOrder collection exists and is writable');
        } catch (e) {
          print('❌ [DEBUG] purchaseOrder collection access issue: $e');
        }
      } else {
        print('✅ [DEBUG] Documents found in purchaseOrder collection:');
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          print('  📄 Document ID: ${doc.id}');
          print('    Status: ${data['status'] ?? 'null'}');
          print('    Supplier: ${data['supplierName'] ?? 'null'}');
          print('    Created: ${data['createdDate'] ?? 'null'}');
          print('    ---');
        }
      }
      
    } catch (e) {
      print('❌ [ERROR] Firestore test failed: $e');
    }
  }
}
