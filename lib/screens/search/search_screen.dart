import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/discussion.dart';
import '../../repositories/discussion_repository.dart';
import '../../widgets/discussion_list.dart';
import '../../widgets/discussion_skeleton.dart';
import '../../widgets/notice.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.discussions});

  final DiscussionRepository discussions;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  int _requestId = 0;
  List<Discussion>? _results;
  bool _loading = false;
  bool _failed = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(value));
  }

  Future<void> _search(String value) async {
    _debounce?.cancel();
    final query = value.trim();
    final request = ++_requestId;
    if (query.length < 2) {
      setState(() {
        _results = null;
        _loading = false;
        _failed = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final results = await widget.discussions.searchDiscussions(query);
      if (!mounted || request != _requestId) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || request != _requestId) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  void _clear() {
    _controller.clear();
    _search('');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: TextField(
          controller: _controller,
          onChanged: _onChanged,
          onSubmitted: _search,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Rechercher une discussion',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Effacer',
                    onPressed: _clear,
                    icon: const Icon(Icons.close, size: 18),
                  ),
          ),
        ),
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_failed) {
      return CenteredNotice(
        text: 'La recherche a échoué. Vérifie ta connexion, puis réessaie.',
        action: FilledButton(
          onPressed: () => _search(_controller.text),
          child: const Text('Réessayer'),
        ),
      );
    }
    if (_loading) return const DiscussionSkeletonList();

    final results = _results;
    if (results == null) {
      return const CenteredNotice(
        icon: Icons.search,
        text: 'Cherche un mot dans les titres et les messages.',
      );
    }
    if (results.isEmpty) {
      return CenteredNotice(
        text: 'Aucune discussion ne correspond à « ${_controller.text.trim()} ».',
      );
    }
    return DiscussionList(items: results);
  }
}
