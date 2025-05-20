import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReceptionistCommissionsPage extends StatefulWidget {
  final int receptionistId;

  const ReceptionistCommissionsPage({Key? key, required this.receptionistId})
      : super(key: key);

  @override
  State<ReceptionistCommissionsPage> createState() =>
      _ReceptionistCommissionsPageState();
}

class _ReceptionistCommissionsPageState
    extends State<ReceptionistCommissionsPage> {
  final supabase = Supabase.instance.client;
  DateTime? startDate;
  DateTime? endDate;
  List<Map<String, dynamic>> commissions = [];
  bool isLoading = true;
  double commissionPercentage = 0.0; // Store the receptionist's commission percentage

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    startDate = DateTime(today.year, today.month, 1); // First day of current month
    endDate = DateTime(today.year, today.month, today.day); // Today
    fetchReceptionistData();
  }

  Future<void> fetchReceptionistData() async {
    try {
      // First get the receptionist's commission percentage
      final receptionistData = await supabase
          .from('receptionist')
          .select('commission_percentage')
          .eq('receptionist_id', widget.receptionistId)
          .single();
      
      setState(() {
        commissionPercentage = (receptionistData['commission_percentage'] as num).toDouble();
      });
      
      // Then fetch appointments
      await fetchCommissions();
    } catch (e) {
      print("Error fetching receptionist data: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchCommissions() async {
    setState(() => isLoading = true);

    try {
      print("Fetching commissions for receptionistId: ${widget.receptionistId}");

      // Join the appointment table with the service table to get service details
      final response = await supabase
          .from('appointment')
          .select('book_id, booking_date, service_id, service(service_name, service_price)')
          .eq('receptionist_id', widget.receptionistId)
          .gte('booking_date', startDate!.toIso8601String())
          .lte('booking_date', endDate!.add(const Duration(days: 1)).toIso8601String())
          .eq('status', 'Completed'); // Only count completed appointments

      print("Supabase response: $response");

      // Transform the response to include calculated commission
      final transformedResponse = List<Map<String, dynamic>>.from(response).map((item) {
        final servicePrice = item['service']?['service_price'] ?? 0.0;
        final commissionAmount = servicePrice * (commissionPercentage / 100);
        
        return {
          'booking_date': item['booking_date'],
          'service_name': item['service']?['service_name'] ?? 'Unknown',
          'service_price': servicePrice,
          'receptionist_commission': commissionAmount,
        };
      }).toList();

      setState(() {
        commissions = transformedResponse;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching commissions: $e");
      setState(() {
        commissions = [];
        isLoading = false;
      });
    }
  }

  Future<void> selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: startDate!, end: endDate!),
    );

    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
      await fetchCommissions();
    }
  }

  double getTotalCommission() {
    return commissions.fold(0.0, (sum, item) {
      final amount = item['receptionist_commission'] ?? 0;
      return sum + (amount as num).toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Receptionist Commissions"),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () => selectDateRange(context),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : commissions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "No Commissions Available.",
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Date Range: ${dateFormat.format(startDate!)} to ${dateFormat.format(endDate!)}",
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => selectDateRange(context),
                        child: const Text("Change Date Range"),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "From ${dateFormat.format(startDate!)} to ${dateFormat.format(endDate!)}",
                            style: const TextStyle(fontSize: 16),
                          ),
                          Text(
                            "Rate: ${commissionPercentage.toStringAsFixed(1)}%",
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.attach_money, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(
                              "Total Commission: ₱${getTotalCommission().toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: Text(
                              "Date",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              "Service",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              "Commission",
                              style: TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      Expanded(
                        child: ListView.builder(
                          itemCount: commissions.length,
                          itemBuilder: (context, index) {
                            final item = commissions[index];
                            final date = DateTime.tryParse(
                                item['booking_date'] ?? '');
                            final formattedDate = date != null
                                ? dateFormat.format(date)
                                : 'N/A';
                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: Text(formattedDate),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        item['service_name'] ?? 'N/A',
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        '₱${(item['receptionist_commission'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.end,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}