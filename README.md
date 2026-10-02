# TypeSafe AI Zig SDK

SDK nativo em Zig para a [TypeSafe AI](https://typesafe.ai), sem dependências externas.
Os nomes públicos do SDK original foram mantidos sempre que há um equivalente em Zig:
`TypeSafeClient`, `systemOne`, `Models`, `choice`, `noul`, `score`, `RetryPolicy` e os nomes de erro HTTP.

## Requisitos

- Zig 0.14.0 ou mais recente.
- Uma chave em `TYPESAFE_API_KEY` (ou `apiKey` na configuração).

## Instalação

Adicione este repositório ao `build.zig.zon` e importe o módulo:

```zig
const typesafe = b.dependency("typesafe_sdk", .{
    .target = target,
    .optimize = optimize,
}).module("typesafe");
exe.root_module.addImport("typesafe", typesafe);
```

## Uso

```zig
const std = @import("std");
const typesafe = @import("typesafe");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = try typesafe.TypeSafeClient.init(allocator, .{});
    defer client.deinit();

    var questions = typesafe.Questions.init(allocator);
    defer questions.deinit();
    try questions.put("billing", typesafe.noul(
        .{ .string = "Is this about billing?" },
        null,
    ));

    var result = try client.systemOne(.{
        .state = .{ .string = "I was charged twice." },
        .questions = &questions,
    }, .{});
    defer result.deinit();

    std.debug.print("model: {s}\n", .{result.value.model});
}
```

`systemOne` e `Models.list` retornam `std.json.Parsed`, que deve receber `deinit`.
Como Zig 0.14 não possui o modelo async/await do JavaScript, as chamadas de rede são síncronas;
`APIPromise` permanece disponível como contêiner de compatibilidade para dados e metadados.

## Desenvolvimento

```sh
zig build test
zig fmt --check build.zig src
zig build docs
```
