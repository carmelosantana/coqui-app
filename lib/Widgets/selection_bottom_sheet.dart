import 'package:flutter/material.dart';
import 'package:coqui_app/Models/request_state.dart';
import 'package:async/async.dart';

class SelectionBottomSheet<T> extends StatefulWidget {
  final Widget header;
  final Future<List<T>> Function() fetchItems;
  final T? currentSelection;

  /// Optional custom item builder. When provided, replaces the default
  /// [RadioListTile] rendering. The builder receives the item, whether
  /// it is currently selected, and a callback to call when selected.
  final Widget Function(T item, bool selected, ValueChanged<T?> onSelected)?
      itemBuilder;

  const SelectionBottomSheet({
    super.key,
    required this.header,
    required this.fetchItems,
    required this.currentSelection,
    this.itemBuilder,
  });

  @override
  State<SelectionBottomSheet<T>> createState() => _SelectionBottomSheetState();
}

class _SelectionBottomSheetState<T> extends State<SelectionBottomSheet<T>> {
  static final _itemsBucket = PageStorageBucket();

  T? _selectedItem;
  List<T> _items = [];

  var _state = RequestState.uninitialized;
  late CancelableOperation _fetchOperation;

  @override
  void initState() {
    super.initState();

    _items = _itemsBucket.readState(context, identifier: widget.key) ?? [];
    _selectedItem = widget.currentSelection;

    _fetchOperation = CancelableOperation.fromFuture(_fetchItems());
  }

  @override
  void dispose() {
    _fetchOperation.cancel();
    super.dispose();
  }

  Future<void> _fetchItems() async {
    setState(() {
      _state = RequestState.loading;
    });

    try {
      _items = await widget.fetchItems();
      _state = RequestState.success;

      if (mounted) {
        _itemsBucket.writeState(context, _items, identifier: widget.key);
      }
    } catch (e) {
      _state = RequestState.error;
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: widget.header),
              if (_items.isNotEmpty && _state == RequestState.loading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
          const Divider(),
          Expanded(
            child: _buildBody(context),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(widget.currentSelection);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (_selectedItem != null) {
                    Navigator.of(context).pop(_selectedItem);
                  }
                },
                child: const Text('Select'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_state == RequestState.error) {
      return Center(
        child: Text(
          'An error occurred while fetching the items.'
          '\nCheck your server connection and try again.',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    } else if (_state == RequestState.loading && _items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    } else if (_state == RequestState.success || _items.isNotEmpty) {
      if (_items.isEmpty) {
        return const Center(child: Text('No items found.'));
      }

      return RefreshIndicator(
        onRefresh: () async {
          _fetchOperation = CancelableOperation.fromFuture(_fetchItems());
        },
        child: RadioGroup<T>(
          groupValue: _selectedItem,
          onChanged: (value) {
            setState(() {
              _selectedItem = value;
            });
          },
          child: ListView.builder(
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              final isSelected = item == _selectedItem;

              if (widget.itemBuilder != null) {
                return widget.itemBuilder!(item, isSelected, (value) {
                  setState(() {
                    _selectedItem = value;
                  });
                });
              }

              return RadioListTile<T>(
                title: Text(item.toString()),
                value: item,
                isThreeLine: false,
              );
            },
          ),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }
}

Future<T?> showSelectionBottomSheet<T>({
  ValueKey? key,
  required BuildContext context,
  required Widget header,
  required Future<List<T>> Function() fetchItems,
  required T? currentSelection,
  Widget Function(T item, bool selected, ValueChanged<T?> onSelected)?
      itemBuilder,
}) async {
  return await showModalBottomSheet<T>(
    context: context,
    builder: (context) {
      return SelectionBottomSheet<T>(
        key: key,
        header: header,
        fetchItems: fetchItems,
        currentSelection: currentSelection,
        itemBuilder: itemBuilder,
      );
    },
    isDismissible: false,
    enableDrag: false,
  );
}
