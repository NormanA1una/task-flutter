import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'task.dart';
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';

class TaskProvider with ChangeNotifier {
  List<Task> tasks = [];
  Box tasksBox;
  FirebaseFirestore firestore;
  FirebaseAuth auth;
  StreamSubscription<QuerySnapshot>? tasksSubscription;

  TaskProvider({
    Box? tasksBox,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : tasksBox = tasksBox ?? Hive.box('tasksBox'),
        firestore = firestore ?? FirebaseFirestore.instance,
        auth = auth ?? FirebaseAuth.instance {
    initTasksListener();
  }

  List<Task> get listTasks => tasks;

  void initTasksListener() {
    final user = auth.currentUser;
    if (user != null) {
      tasksSubscription?.cancel();
      tasksSubscription = firestore
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .snapshots()
          .listen((snapshot) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          tasks = snapshot.docs.map((doc) => Task.fromMap(doc.data())).toList();
          _updateLocalStorage();
          notifyListeners();
        });
      }, onError: (error) {
        log("Error al escuchar cambios en las tareas: $error");
      });
    }
  }

  void _updateLocalStorage() {
    tasksBox.clear();
    for (var task in tasks) {
      tasksBox.put(task.id, task.toMap());
    }
  }

  Future<void> addTask(String description) async {
    final task = Task(id: const Uuid().v4(), description: description);
    log("Tarea agregada: ${task.toMap()}");
    try {
      await _saveTaskToFirestore(task);
      tasks.add(task);
      tasksBox.put(task.id, task.toMap());
      notifyListeners();
    } catch (e) {
      log("Error al agregar tarea: $e");
    }
  }

  Future<void> _saveTaskToFirestore(Task task) async {
    var user = auth.currentUser;
    if (user == null) {
      throw Exception("Usuario no autenticado");
    }
    await firestore
        .collection('users')
        .doc(user.uid)
        .collection('tasks')
        .doc(task.id)
        .set(task.toMap());
  }

  Future<void> deleteTask(String id) async {
    var user = auth.currentUser;
    if (user == null) {
      log("Error: Usuario no autenticado");
      return;
    }
    try {
      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .doc(id)
          .delete();
      tasks.removeWhere((task) => task.id == id);
      await tasksBox.delete(id);
      notifyListeners();
    } catch (e) {
      log("Error al eliminar tarea: $e");
    }
  }

  Future<void> toggleTaskCompleted(String id) async {
    var task = tasks.firstWhere((task) => task.id == id);
    task.isCompleted = !task.isCompleted;
    try {
      await _saveTaskToFirestore(task);
      notifyListeners();
    } catch (e) {
      log("Error al actualizar tarea: $e");
      // Revertir el cambio si hay un error
      task.isCompleted = !task.isCompleted;
    }
  }

  @override
  void dispose() {
    tasksSubscription?.cancel();
    super.dispose();
  }
}
