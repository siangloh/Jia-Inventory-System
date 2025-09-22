import 'dart:async';

// temporary mock dao for work order validation
// this will be replaced with the real WorkOrderDao when the job management module is ready
class MockWorkOrderDao {
  
  // mock work order data for development
  static final Map<String, Map<String, dynamic>> _mockWorkOrders = {
    'WO-2025-001': {
      'customer_name': 'Mr. Tan Ah Beng',
      'vehicle_info': 'Toyota Vios - WXY 1234',
      'job_type': 'Brake Service',
      'status': 'In Progress'
    },
    'WO-2025-015': {
      'customer_name': 'Ms. Lim Siew Mei',
      'vehicle_info': 'Honda City - ABC 5678',
      'job_type': 'Oil Change',
      'status': 'Completed'
    },
    'WO-2025-023': {
      'customer_name': 'Mr. Ahmad bin Ismail',
      'vehicle_info': 'Proton Saga - DEF 9012',
      'job_type': 'Tire Replacement',
      'status': 'Pending'
    },
    'WO-2025-045': {
      'customer_name': 'Mr. Raj Kumar',
      'vehicle_info': 'Perodua Myvi - GHI 3456',
      'job_type': 'Battery Replacement',
      'status': 'In Progress'
    }
  };

  // validate work order number and return details if found
  Future<Map<String, dynamic>?> getMockWorkOrder(String workOrderNumber) async {
    // simulate database delay
    await Future.delayed(const Duration(milliseconds: 300));
    
    // return mock data if work order exists
    return _mockWorkOrders[workOrderNumber.toUpperCase()];
  }

  // check if work order number exists
  Future<bool> isWorkOrderValid(String workOrderNumber) async {
    final workOrder = await getMockWorkOrder(workOrderNumber);
    return workOrder != null;
  }

  // get all mock work order numbers for testing
  List<String> getAllMockWorkOrderNumbers() {
    return _mockWorkOrders.keys.toList();
  }
}
