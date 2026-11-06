# Ubuntu 22.04 Build Note

## 対象環境

- OS: Ubuntu 22.04 (x86_64)
- Swift: 6.4.1 (swiftly)
- Clang: 21.0.0 (Swift toolchain bundled)
- GCC / G++: 11.4.0
- Build system: Swift Package Manager
- Application: ZIKUU AdminDashboard
- Dependency: swift-nio-ssl / CNIOBoringSSL

## 1. 問題

Ubuntu 22.04でAdminDashboardをビルドすると、`swift-nio-ssl` のC++コードのコンパイルに失敗する。

```text
CNIOBoringSSL_base.h:409:10:
fatal error: 'memory' file not found
```

`<memory>` はC++標準ライブラリのヘッダー。

`build-essential` および `libstdc++-11-dev` はインストール済みだった。

## 2. 原因

Swift 6.4.1に付属するClang 21が、GCC 11とGCC 12を検出し、GCC 12を自動選択していた。

```text
Found candidate GCC installation:
/usr/lib/gcc/x86_64-linux-gnu/11

Found candidate GCC installation:
/usr/lib/gcc/x86_64-linux-gnu/12

Selected GCC installation:
/usr/lib/gcc/x86_64-linux-gnu/12
```

しかし、GCC 12用のC++標準ライブラリ開発ファイルが揃っていなかった。

その結果、Clangが `<memory>` などの標準ヘッダーを発見できなかった。

さらに、コンパイル時のGCC選択を修正した後も、リンク時に次のエラーが発生した。

```text
/usr/bin/ld.gold: error: cannot find -lstdc++
```

これも、GCC 11のC++標準ライブラリ検索パスがリンク時に正しく指定されていなかったことが原因だった。

## 3. 解決方法

ClangにGCC 11を明示的に使用させ、リンカーにもGCC 11のライブラリ検索パスを指定する。

```bash
swift build \
  -Xcc --gcc-install-dir=/usr/lib/gcc/x86_64-linux-gnu/11 \
  -Xlinker -L/usr/lib/gcc/x86_64-linux-gnu/11
```

### オプションの意味

`-Xcc --gcc-install-dir=...`

C/C++コンパイル時に使用するGCCインストールディレクトリを指定する。これにより、GCC 11のC++標準ライブラリヘッダーを使用できる。

`-Xlinker -L...`

リンク時のライブラリ検索パスにGCC 11のディレクトリを追加する。これにより `-lstdc++` を解決できる。

## 4. 動作確認

上記のビルドオプションを指定した結果、以下を確認した。

- CNIOBoringSSLのC++コンパイル成功
- `libstdc++` のリンク成功
- AdminDashboardのビルド成功
- AdminDashboardの起動・実行成功

Swift、GCC、AdminDashboard、ZIKUU Swift Frameworkのソースコード変更は不要だった。


### Build

```bash
swift build \
  -Xcc --gcc-install-dir=/usr/lib/gcc/x86_64-linux-gnu/11 \
  -Xlinker -L/usr/lib/gcc/x86_64-linux-gnu/11
```

### Run
```bash
swift run \
  -Xcc --gcc-install-dir=/usr/lib/gcc/x86_64-linux-gnu/11 \
  -Xlinker -L/usr/lib/gcc/x86_64-linux-gnu/11 \
  AdminDashboardService
```

## 5. 診断コマンド

### ツールチェーンのバージョン

```bash
swift --version
clang++ --version
g++ --version
```

### C++標準ライブラリのインストール状況

```bash
dpkg -l | grep -E 'libstdc\+\+-[0-9]+-dev|build-essential'
```

### Clangのヘッダー探索パス

```bash
echo '#include <memory>' | \
  clang++ -x c++ -std=c++17 -E -v -o /dev/null -
```

### GCC 11の明示指定によるコンパイル確認

```bash
echo '#include <memory>' | \
  clang++ \
  --gcc-install-dir=/usr/lib/gcc/x86_64-linux-gnu/11 \
  -x c++ -std=c++17 -fsyntax-only -
```

### C++標準ライブラリのリンク対象

```bash
g++ -print-file-name=libstdc++.so
```

## 6. 注意事項

この問題は、Swift FrameworkやAdminDashboardのソースコードに起因するものではなく、ローカルのツールチェーンとGCC開発環境の組み合わせによるもの。

`--gcc-install-dir` と `-L` のパスは環境依存であり、別のUbuntuやFedora環境でそのまま利用できるとは限らない。

GCC 12の開発パッケージを正しく導入することでも解決する可能性はあるが、今回は既存のGCC 11を利用する方法で検証した。

---

**検証日:** 2026-11-06  
**結果:** Build / Run successful