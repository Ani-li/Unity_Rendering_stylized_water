# Constant intrinsic

Use the [`IsConstantExpression`](xref:Unity.Burst.CompilerServices.Constant.IsConstantExpression*) intrinsic to check if a given expression is constant at compile-time:

```c#
using static Unity.Burst.CompilerServices.Constant;

var somethingWhichWillBeConstantFolded = math.pow(42.0f, 42.0f);

if (IsConstantExpression(somethingWhichWillBeConstantFolded))
{
    // Burst knows that somethingWhichWillBeConstantFolded is a compile-time constant
}
```

This is useful to check if a complex expression is always constant folded. You can use it for optimizations for a known constant value. For example, if you want to implement a `pow`-like function for integer powers:

```c#
using static Unity.Burst.CompilerServices.Constant;

public static float MyAwesomePow(float f, int i)
{
    if (IsConstantExpression(i) && (2 == i))
    {
        return f * f;
    }
    else
    {
        return math.pow(f, (float)i);
    }
}
```

The `IsConstantExpression` check means that Burst always removes the branch  if `i` isn't constant, because the if condition is false. This means that if `i` is constant and is equal to 2, you can use a more optimal simple multiply instead.

>[!NOTE]
> Constant folding only takes place during optimizations. If you've disabled optimizations, the intrinsic returns false.