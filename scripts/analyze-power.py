import math

refine = [54316, 47488, 50055, 46077, 49724, 49381]
noref = [47049, 44344, 45029, 48229, 65325, 46300]
# earlier no-state observations from the first refine-value experiment
prior_nostate = [47891, 46382, 80080, 69273, 48341]


def stats(v):
    n = len(v)
    m = sum(v) / n
    sd = math.sqrt(sum((x - m) ** 2 for x in v) / (n - 1))
    return n, m, sd


for label, v in (("refine (forced /refine)", refine),
                 ("no-refine (control)", noref),
                 ("no-state (all: control + prior)", noref + prior_nostate)):
    n, m, sd = stats(v)
    print(f"  {label:34s} n={n:2d}  mean={m:8.0f}  sd={sd:7.0f}  "
          f"range={min(v)}-{max(v)}")

n1, m1, s1 = stats(refine)
n2, m2, s2 = stats(noref)
se = math.sqrt(s1 ** 2 / n1 + s2 ** 2 / n2)
t = (m1 - m2) / se
df = (s1**2/n1 + s2**2/n2) ** 2 / ((s1**2/n1)**2/(n1-1) + (s2**2/n2)**2/(n2-1))
print(f"\n  difference (refine - control) = {m1 - m2:+.0f} tokens "
      f"({(m1-m2)/m2*100:+.2f}%)")
print(f"  Welch t = {t:.3f}, df ~ {df:.1f}  -> p ~ {'>0.9' if abs(t) < 0.2 else 'see table'}")
print(f"  95% CI on the difference ~ {m1-m2:+.0f} +/- {1.96*se:.0f} tokens")

# smallest effect detectable at this n
pooled = math.sqrt((s1**2 + s2**2) / 2)
mde = 2.8 * pooled / math.sqrt(n1)          # ~80% power, alpha .05, two-sided
print(f"\n  minimum detectable effect at n={n1}/arm: ~{mde:.0f} tokens "
      f"({mde/m2*100:.1f}% of control mean)")
print(f"  observed effect is {abs(m1-m2)/mde:.2f}x the MDE -> "
      f"{'well inside noise' if abs(m1-m2) < mde else 'detectable'}")
