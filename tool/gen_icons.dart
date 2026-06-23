import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final src = img.decodeImage(File('assets/images/logo.png').readAsBytesSync());
  if (src == null) { print('falha a ler logo'); return; }

  // Coloca a logo sobre fundo branco (caso tenha transparência) e quadrado
  img.Image square(int size) {
    final canvas = img.Image(width: size, height: size, numChannels: 4);
    img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 255));
    final resized = img.copyResize(src, width: size, height: size);
    img.compositeImage(canvas, resized);
    return canvas;
  }

  void write(String path, int size) {
    File(path).writeAsBytesSync(img.encodePng(square(size)));
    print('escrito $path (${size}x$size)');
  }

  write('web/favicon.png', 64);
  write('web/icons/Icon-192.png', 192);
  write('web/icons/Icon-512.png', 512);
  write('web/icons/Icon-maskable-192.png', 192);
  write('web/icons/Icon-maskable-512.png', 512);
}
