# Unit Test Template (unit-test-case-generator)

每个测试文件必须满足：

1. 用例标题前缀包含 6 类：
- `normal:`
- `boundary:`
- `invalid:`
- `conflict:`
- `regression:`
- `combined:`

2. 每条用例使用 AAA 结构注释：
- `// Arrange`
- `// Act`
- `// Assert`

3. 断言只关注输入输出与可观察行为，不绑定内部实现细节。

## 最小示例（Hypium）

```ts
it('normal: td-20260411-example', 0, () => {
  // Arrange
  const input = 1;
  // Act
  const output = input + 1;
  // Assert
  expect(output).assertEqual(2);
});
```

## 最小示例（Jest）

```ts
it('normal: td-20260411-example', () => {
  // Arrange
  const input = 1;
  // Act
  const output = input + 1;
  // Assert
  expect(output).toBe(2);
});
```
