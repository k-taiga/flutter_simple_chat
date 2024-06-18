import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // Firebaseの初期化の前処理
  WidgetsFlutterBinding.ensureInitialized();
  // 実際の初期化処理
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

const collectionKey = 'k_taiga_todo';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Item> items = [];
  final TextEditingController textEditingController = TextEditingController();
  late FirebaseFirestore firestore;

  @override
  void initState() {
    super.initState();
    firestore = FirebaseFirestore.instance;
    watch();
  }

  // データ更新監視
  Future<void> watch() async {
    // snapshotの変更をlistenで監視する
    firestore.collection(collectionKey).snapshots().listen((event) {
      setState(() {
        // reversedで逆順にしているのは、新しいデータが上に来るようにするため
        items = event.docs.reversed
            // mapでFirestoreのデータをItemクラスに変換
            .map(
              // event.docs.reversedした中身をdocumentに入れている
              (document) => Item.fromSnapshot(document.id, document.data()),
            )
            // toListでListに変換 growable: falseはリストのサイズを固定するため
            .toList(growable: false);
      });
    });
  }

  // 保存する
  Future<void> save() async {
    // collectionKeyを下にcollectionを取得
    final collection = firestore.collection(collectionKey);
    final now = DateTime.now();
    // 時間をkeyに保存する ミリ秒は時間はユニークになるため
    await collection
        .doc(now.microsecondsSinceEpoch.toString())
        .set({"date": now, "text": textEditingController.text});
    textEditingController.text = "";
  }

  // 完了・未完了に変更する
  Future<void> complete(Item item) async {
    final collection = firestore.collection(collectionKey);
    await collection.doc(item.id).set({
      // itemのcompletedを反転して保存
      "completed": !item.completed,
      // merge: trueで既存のデータとマージする
    }, SetOptions(merge: true));
  }

  // 削除する
  Future<void> delete(String id) async {
    final collection = firestore.collection(collectionKey);
    await collection.doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('TODO')),
        body: ListView.builder(
          itemBuilder: (context, index) {
            // 0番目は入力フォームとして使う
            if (index == 0) {
              return ListTile(
                title: TextField(
                  controller: textEditingController,
                ),
                trailing: ElevatedButton(
                  onPressed: () {
                    save();
                  },
                  child: const Text('保存'),
                ),
              );
            }
            // 1番目以降はリスト表示
            final item = items[index - 1];
            // swipeで削除できるようにDismissibleでラップ
            return Dismissible(
              // swipeされたら実行される keyを一意のもので指定する
              key: Key(item.id),
              onDismissed: (direction) {
                delete(item.id);
              },
              child: ListTile(
                // itemのcompletedがtrueならチェックマークを表示 falseならチェックマークを表示しない
                leading: Icon(item.completed
                    ? Icons.check_box
                    : Icons.check_box_outline_blank),
                onTap: () {
                  complete(item);
                },
                title: Text(item.text),
                subtitle: Text(
                  // -を/に変換して19文字まで表示(秒まで表示すると見づらいため)
                  item.date.toString().replaceAll('-', '/').substring(0, 19),
                ),
              ),
            );
          },
          itemCount: items.length + 1,
        ));
  }
}

class Item {
  const Item(
      {required this.id,
      required this.text,
      required this.completed,
      required this.date});
  final String id;
  final String text;
  final bool completed;
  final DateTime date;

  // factory constructorとはフィールド情報から離れた値でインスタンスを生成するためのコンストラクタ
  // この場合はFirestoreから取得したデータをItemクラスに変換するためのコンストラクタ
  factory Item.fromSnapshot(String id, Map<String, dynamic> document) {
    return Item(
      id: id,
      text: document['text'].toString() ?? '',
      completed: document['completed'] ?? false,
      date: (document['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
