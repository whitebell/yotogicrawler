# yotogicrawler

## 何

東方夜伽話とねちょこんの作品回収するやつ。

## 必要なものと使い方

- Perl処理系

Windowsなら[Strawberry Perl](https://strawberryperl.com/)。他のOSなら自分でどうにかして。*nix系ならだいたい入ってる気もするけど。
多分標準で入ってないモジュール使ってるので、何か足りなかったらターミナルで

```shell
cpan install HTML::TreeBuilder::XPath
```

とかしてインストールすること。

あとは

```shell
perl yotogi.pl
perl comp.pl
```

で全部回収します。comp1～14.json, cache.json は更新確認用のキャッシュなので削除しないこと。更新があれば同じコマンド実行してやればキャッシュ確認した上で新規・更新作品だけ回収します。

夜伽話回収時にターミナルが文字化けするなら yotogi.json の `term_encoding` を変えてみるといいかも。Windowsなら `cp932`、あとは `utf8` とか。古いLinuxだと `eucjp` とかまだあるかもしれないけど。

## License

MIT。
