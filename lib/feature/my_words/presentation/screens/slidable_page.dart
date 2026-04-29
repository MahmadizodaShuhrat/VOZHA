import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class SlidablePage extends StatefulWidget {
  const SlidablePage({super.key});

  @override
  State<SlidablePage> createState() => _SlidablePageState();
}

class _SlidablePageState extends State<SlidablePage> with SingleTickerProviderStateMixin{
  late final controller =  SlidableController(this);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Slidable(
  key: ValueKey(0),
  controller: controller,
  endActionPane: ActionPane(
    motion: ScrollMotion(),
    children: [
      SlidableAction(
        onPressed: (value) {},
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        icon: Icons.archive,
        label: "Archive",
      ),
      SlidableAction(
        onPressed: (value) {},
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        icon: Icons.remove,
        label: "Delete",
      ),
      SlidableAction(
        onPressed: (value) {},
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        icon: Icons.share,
        label: "Share",
      ),
    ],
  ),

  child: ListTile(
    title: Text("Slide me"),
  ),
),
    ));
  }
}
