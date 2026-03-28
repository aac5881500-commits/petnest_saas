import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/pet_service.dart';

class MyPetPage extends StatefulWidget {
  const MyPetPage({super.key});

  @override
  State<MyPetPage> createState() => _MyPetPageState();
}

class _MyPetPageState extends State<MyPetPage> {
  final nameController = TextEditingController();

  Future<void> _addPet() async {
    if (nameController.text.isEmpty) return;

    await PetService.instance.createPet(
      name: nameController.text,
      type: 'cat',
    );

    nameController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的寵物')),
      body: Column(
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: '寵物名稱'),
          ),
          ElevatedButton(
            onPressed: _addPet,
            child: const Text('新增寵物'),
          ),
          Expanded(
            child: StreamBuilder(
              stream: PetService.instance.streamMyPets(),
              builder: (context, snapshot) {
                final pets = snapshot.data ?? [];

                return ListView(
                  children: pets.map((p) {
                    return ListTile(
                      title: Text(p['name']),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}