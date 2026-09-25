// Проверка ввода инструмента по его же JSON-схеме (TOOLS в plan.ts — единственный источник).
// Нужна, потому что Gemini не держит схему строго, как `strict` у Claude:
// кривой план не должен дойти до телефона. Пропущенное поле, которое может быть null,
// дополняется null («не задаю / не меняю»), — Gemini часто опускает null-поля.

// deno-lint-ignore no-explicit-any
type Schema = Record<string, any>;

const typeOk = (t: string, v: unknown): boolean => {
  if (t === "null") return v === null;
  if (t === "string") return typeof v === "string";
  if (t === "integer") return typeof v === "number" && Number.isInteger(v);
  if (t === "number") return typeof v === "number" && Number.isFinite(v);
  if (t === "boolean") return typeof v === "boolean";
  if (t === "array") return Array.isArray(v);
  if (t === "object") return typeof v === "object" && v !== null && !Array.isArray(v);
  return false;
};

export const allowsNull = (s: Schema): boolean =>
  s.type === "null" || (Array.isArray(s.anyOf) && s.anyOf.some(allowsNull));

/// Возвращает нормализованное значение и список ошибок по путям («ops[2].fields.kind: …»).
export function checkSchema(value: unknown, s: Schema, path = ""): { value: unknown; errors: string[] } {
  const at = path || "план";
  if (Array.isArray(s.anyOf)) {
    for (const alt of s.anyOf) {
      const r = checkSchema(value, alt, path);
      if (r.errors.length === 0) return r;
    }
    return { value, errors: [`${at}: не подходит ни один вариант (${s.anyOf.map((a: Schema) => a.type).join(" | ")})`] };
  }
  if (!typeOk(s.type, value)) return { value, errors: [`${at}: нужен ${s.type}, пришло ${JSON.stringify(value)}`] };
  if (s.enum && !s.enum.includes(value)) return { value, errors: [`${at}: ${JSON.stringify(value)} не из ${s.enum.join("|")}`] };

  if (s.type === "array") {
    const errors: string[] = [];
    const out = (value as unknown[]).map((v, i) => {
      const r = checkSchema(v, s.items, `${path}[${i}]`);
      errors.push(...r.errors);
      return r.value;
    });
    return { value: out, errors };
  }
  if (s.type === "object") {
    const obj = value as Record<string, unknown>;
    const props: Record<string, Schema> = s.properties ?? {};
    const errors: string[] = [];
    const out: Record<string, unknown> = {};
    for (const k of Object.keys(obj)) {
      if (!(k in props) && s.additionalProperties === false) errors.push(`${path ? path + "." : ""}${k}: лишнее поле`);
    }
    for (const [k, ps] of Object.entries(props)) {
      const p = path ? `${path}.${k}` : k;
      if (!(k in obj)) {
        if ((s.required ?? []).includes(k) && !allowsNull(ps)) errors.push(`${p}: нет поля`);
        else out[k] = null;
        continue;
      }
      const r = checkSchema(obj[k], ps, p);
      errors.push(...r.errors);
      out[k] = r.value;
    }
    return { value: out, errors };
  }
  return { value, errors: [] };
}

/// Та же схема, но поля, которые могут быть null, — необязательные. Для провайдеров, которые
/// сами отклоняют вызов с пропущенным полем (Groq): модель их часто опускает, а сервер
/// дописывает null сам (checkSchema).
export function relaxNullable(s: Schema): Schema {
  if (Array.isArray(s.anyOf)) return { ...s, anyOf: s.anyOf.map(relaxNullable) };
  if (s.type === "array" && s.items) return { ...s, items: relaxNullable(s.items) };
  if (s.type !== "object" || !s.properties) return s;
  const properties = Object.fromEntries(Object.entries(s.properties as Record<string, Schema>).map(([k, v]) => [k, relaxNullable(v)]));
  const required = (s.required ?? []).filter((k: string) => !allowsNull((s.properties as Record<string, Schema>)[k]));
  return { ...s, properties, required };
}
