import 'dart:async';

// import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/task.dart';
import 'package:task_manager/task_provider.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

@GenerateMocks([
  FirebaseFirestore,
  FirebaseAuth,
  User,
  Box,
  CollectionReference<Map<String, dynamic>>,
  DocumentReference<Map<String, dynamic>>,
  QuerySnapshot<Map<String, dynamic>>,
  DocumentSnapshot<Map<String, dynamic>>,
  QueryDocumentSnapshot<Map<String, dynamic>>,
])
import 'task_provider_test.mocks.dart';

void main() {
  // Agregar esta línea al principio de la función main
  TestWidgetsFlutterBinding.ensureInitialized();

  late TaskProvider taskProvider;
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late MockBox mockBox;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    mockBox = MockBox();

    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('test-user-id');

    // Configurar el mock para collection, doc y snapshots
    final mockCollection = MockCollectionReference<Map<String, dynamic>>();
    final mockDocumentReference = MockDocumentReference<Map<String, dynamic>>();
    final mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();

    when(mockFirestore.collection(any)).thenReturn(mockCollection);
    when(mockCollection.doc(any)).thenReturn(mockDocumentReference);
    when(mockDocumentReference.collection(any)).thenReturn(mockCollection);

    // Configurar el mock para snapshots
    when(mockCollection.snapshots(
      includeMetadataChanges: anyNamed('includeMetadataChanges'),
      source: anyNamed('source'),
    )).thenAnswer((_) => Stream.fromIterable([mockQuerySnapshot]));

    // Configurar el mock para los documentos en el snapshot
    when(mockQuerySnapshot.docs).thenReturn([]);

    // Configurar el mock para el Box de Hive
    when(mockBox.put(any, any)).thenAnswer((_) => Future.value());

    taskProvider = TaskProvider(
      firestore: mockFirestore,
      auth: mockAuth,
      tasksBox: mockBox,
    );
  });

  group('TaskProvider', () {
    test('addTask debería agregar una nueva tarea', () async {
      final mockUsersCollection =
          MockCollectionReference<Map<String, dynamic>>();
      final mockUserDocument = MockDocumentReference<Map<String, dynamic>>();
      final mockTasksCollection =
          MockCollectionReference<Map<String, dynamic>>();
      final mockTaskDocument = MockDocumentReference<Map<String, dynamic>>();

      // Configurar la estructura de Firestore
      when(mockFirestore.collection('users')).thenReturn(mockUsersCollection);
      when(mockUsersCollection.doc('test-user-id'))
          .thenReturn(mockUserDocument);
      when(mockUserDocument.collection('tasks'))
          .thenReturn(mockTasksCollection);
      when(mockTasksCollection.doc(any)).thenReturn(mockTaskDocument);

      // Configurar el mock para aceptar la llamada a set
      when(mockTaskDocument.set(any)).thenAnswer((_) => Future.value());

      // Ejecutar el método que queremos probar
      await taskProvider.addTask('Nueva tarea');

      // Verificar que se llamó a set en el documento de la tarea
      verify(mockTaskDocument.set(argThat(predicate(
          (Map<String, dynamic> data) =>
              data['description'] == 'Nueva tarea' &&
              data['isCompleted'] == false &&
              data['id'] != null)))).called(1);

      // Verificar que la tarea se agregó a la lista local
      expect(taskProvider.tasks.length, 1);
      expect(taskProvider.tasks[0].description, 'Nueva tarea');
      expect(taskProvider.tasks[0].isCompleted, false);
      expect(taskProvider.tasks[0].id, isNotEmpty);

      // Verificar que se llamó a put en el Box de Hive
      verify(mockBox.put(
          any,
          argThat(predicate((dynamic task) =>
              task is Map<String, dynamic> &&
              task['description'] == 'Nueva tarea' &&
              task['isCompleted'] == false &&
              task['id'] != null)))).called(1);
    });

    test('deleteTask debería eliminar una tarea', () async {
      final mockCollection = MockCollectionReference<Map<String, dynamic>>();
      final mockDocumentReference =
          MockDocumentReference<Map<String, dynamic>>();

      when(mockFirestore.collection('users')).thenReturn(mockCollection);
      when(mockCollection.doc('test-user-id'))
          .thenReturn(mockDocumentReference);
      when(mockDocumentReference.collection('tasks'))
          .thenReturn(mockCollection);

      const taskId = 'mock-task-id';
      taskProvider.tasks
          .add(Task(id: taskId, description: 'Tarea para eliminar'));

      // Configuramos el mock para el documento específico
      when(mockCollection.doc(taskId)).thenReturn(mockDocumentReference);

      // Ejecutamos deleteTask
      await taskProvider.deleteTask(taskId);

      // Verificaciones
      verify(mockDocumentReference.delete()).called(1);
      expect(taskProvider.tasks.length, 0);
    });

    test(
        'toggleTaskCompleted debería cambiar el estado de completado de una tarea',
        () async {
      final mockCollection = MockCollectionReference<Map<String, dynamic>>();
      final mockDocumentReference =
          MockDocumentReference<Map<String, dynamic>>();

      when(mockFirestore.collection('users')).thenReturn(mockCollection);
      when(mockCollection.doc('test-user-id'))
          .thenReturn(mockDocumentReference);
      when(mockDocumentReference.collection('tasks'))
          .thenReturn(mockCollection);
      when(mockCollection.doc(any)).thenReturn(mockDocumentReference);

      // Simular una tarea existente
      const taskId = 'mock-task-id';
      final task = Task(
          id: taskId, description: 'Tarea para completar', isCompleted: false);
      taskProvider.tasks.add(task);

      expect(taskProvider.tasks[0].isCompleted, false);

      // Configurar el mock para aceptar la llamada a set
      when(mockDocumentReference.set(any)).thenAnswer((_) => Future.value());

      // Ejecutar toggleTaskCompleted
      await taskProvider.toggleTaskCompleted(taskId);

      // Verificar que se llamó a set en Firestore
      verify(mockDocumentReference.set(argThat(predicate(
              (Map<String, dynamic> data) => data['isCompleted'] == true))))
          .called(1);

      // Verificar que el estado de la tarea cambió localmente
      expect(taskProvider.tasks[0].isCompleted, true);
    });

    /*  test(
        '_initTasksListener debería actualizar las tareas cuando hay cambios en Firestore',
        () async {
      final mockUsersCollection =
          MockCollectionReference<Map<String, dynamic>>();
      final mockUserDocument = MockDocumentReference<Map<String, dynamic>>();
      final mockTasksCollection =
          MockCollectionReference<Map<String, dynamic>>();
      final mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
      final mockQueryDocumentSnapshot =
          MockQueryDocumentSnapshot<Map<String, dynamic>>();

      // Configurar la estructura de Firestore
      when(mockFirestore.collection('users')).thenReturn(mockUsersCollection);
      when(mockUsersCollection.doc('test-user-id'))
          .thenReturn(mockUserDocument);
      when(mockUserDocument.collection('tasks'))
          .thenReturn(mockTasksCollection);

      // Configurar el mock para snapshots
      final streamController =
          StreamController<QuerySnapshot<Map<String, dynamic>>>();
      when(mockTasksCollection.snapshots())
          .thenAnswer((_) => streamController.stream);

      // Configurar el mock para los documentos en el snapshot
      when(mockQuerySnapshot.docs).thenReturn([mockQueryDocumentSnapshot]);
      when(mockQueryDocumentSnapshot.data()).thenReturn({
        'id': 'test-task-id',
        'description': 'Test Task',
        'isCompleted': false,
      });

      // Ejecutar initTasksListener
      taskProvider.initTasksListener();

      // Crear un StreamController para simular los cambios en las tareas
      final tasksStreamController = StreamController<List<Task>>();

      // Reemplazar la lista de tareas con un Stream
      taskProvider.tasks = tasksStreamController.stream.asBroadcastStream();

      // Emitir el snapshot
      streamController.add(mockQuerySnapshot);

      // Esperar a que se actualicen las tareas
      await expectLater(
        taskProvider.tasks,
        emits(isNotEmpty),
      ).timeout(const Duration(seconds: 5));

      // Simular la actualización de tareas
      tasksStreamController
          .add([Task(id: 'test-task-id', description: 'Test Task')]);

      // Cerrar los StreamControllers
      await tasksStreamController.close();
      await streamController.close();
    }); */
  });
}
