import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'spa_details.dart';

class BookmarkedServices extends StatefulWidget {
  final int clientId;

  const BookmarkedServices({Key? key, required this.clientId}) : super(key: key);

  @override
  _BookmarkedServicesState createState() => _BookmarkedServicesState();
}

class _BookmarkedServicesState extends State<BookmarkedServices> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _bookmarks = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchBookmarks();
  }

  @override
  void dispose() {
    // Cancel any ongoing operations before disposing
    _isLoading = false;
    super.dispose();
  }

  Future<void> _fetchBookmarks() async {
    if (!mounted) return;
    
    try {
      setState(() => _isLoading = true);

      final response = await supabase
          .from('bookmark')
          .select('''
            *,
            service:service_id (
              service_id,
              service_name,
              service_price,
              spa:spa_id (
                spa_id,
                spa_name,
                spa_address,
                image_url
              )
            )
          ''')
          .eq('client_id', widget.clientId)
          .order('created_at', ascending: false);

      if (!mounted) return; // Check mounted again after await

      setState(() {
        _bookmarks = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _error = 'Error loading bookmarks: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _removeBookmark(int bookmarkId) async {
    if (!mounted) return;
    
    try {
      await supabase
          .from('bookmark')
          .delete()
          .eq('bookmark_id', bookmarkId);

      if (!mounted) return;
      
      await _fetchBookmarks();
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bookmark removed')),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing bookmark: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bookmarked Services'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchBookmarks,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _bookmarks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No bookmarked services yet',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchBookmarks,
                      child: ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _bookmarks.length,
                        itemBuilder: (context, index) {
                          final bookmark = _bookmarks[index];
                          final service = bookmark['service'];
                          final spa = service['spa'];

                          return Card(
                            margin: EdgeInsets.only(bottom: 16),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SpaDetails(
                                      spaId: spa['spa_id'],
                                    ),
                                  ),
                                );
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (spa['image_url'] != null)
                                    Image.network(
                                      spa['image_url'],
                                      height: 150,
                                      fit: BoxFit.cover,
                                    ),
                                  Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    service['service_name'],
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  Text(
                                                    '₱${service['service_price'].toStringAsFixed(2)}',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.green,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.bookmark_remove),
                                              onPressed: () => _removeBookmark(bookmark['bookmark_id']),
                                              color: Colors.red,
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          spa['spa_name'],
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          spa['spa_address'],
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
