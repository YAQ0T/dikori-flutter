const crypto = require("crypto");
const { getFirestore } = require("./firebaseAdmin");

const MODEL_REGISTRY = new Map();
const FIRESTORE_IN_LIMIT = 30;
const ENABLE_SCAN_FALLBACK_LOG =
  String(process.env.FIRESTORE_SCAN_FALLBACK_LOG || "true").toLowerCase() ===
  "true";
const ARRAY_MEMBERSHIP_FIELDS = new Set([
  "tags",
  "readBy",
  "recommended",
  "newArrivals",
]);

function isPlainObject(value) {
  if (!value || typeof value !== "object") return false;
  return Object.getPrototypeOf(value) === Object.prototype;
}

function isObjectIdLike(value) {
  if (!value || typeof value !== "object") return false;
  return (
    value._bsontype === "ObjectID" ||
    value._bsontype === "ObjectId" ||
    value.constructor?.name === "ObjectId" ||
    typeof value.toHexString === "function"
  );
}

function toObjectIdString(value) {
  if (value == null) return "";
  if (typeof value === "string") return value;
  if (typeof value === "number" || typeof value === "boolean") {
    return String(value);
  }
  if (typeof value.toHexString === "function") {
    return value.toHexString();
  }
  return String(value);
}

function normalizeScalar(value) {
  if (isObjectIdLike(value)) return toObjectIdString(value);
  return value;
}

function deepClone(value) {
  if (value == null) return value;
  if (value instanceof Date) return new Date(value.getTime());
  if (Array.isArray(value)) return value.map((item) => deepClone(item));
  if (isPlainObject(value)) {
    const out = {};
    for (const [key, nested] of Object.entries(value)) {
      out[key] = deepClone(nested);
    }
    return out;
  }
  if (isObjectIdLike(value)) return toObjectIdString(value);
  return value;
}

function sanitizeForStorage(value) {
  if (value === undefined) return undefined;
  if (value === null) return null;
  if (value instanceof Date) return value;
  if (Array.isArray(value)) {
    return value
      .map((item) => sanitizeForStorage(item))
      .filter((item) => item !== undefined);
  }
  if (isObjectIdLike(value)) return toObjectIdString(value);
  if (isPlainObject(value)) {
    const out = {};
    for (const [key, nested] of Object.entries(value)) {
      const cleaned = sanitizeForStorage(nested);
      if (cleaned !== undefined) out[key] = cleaned;
    }
    return out;
  }
  return value;
}

function hydrateFromStorage(value) {
  if (value == null) return value;
  if (Array.isArray(value)) return value.map((item) => hydrateFromStorage(item));
  if (value && typeof value.toDate === "function") return value.toDate();
  if (isObjectIdLike(value)) return toObjectIdString(value);
  if (isPlainObject(value)) {
    const out = {};
    for (const [key, nested] of Object.entries(value)) {
      out[key] = hydrateFromStorage(nested);
    }
    return out;
  }
  return value;
}

function splitPath(path) {
  return String(path || "")
    .split(".")
    .map((part) => part.trim())
    .filter(Boolean);
}

function getByPath(source, path) {
  const parts = splitPath(path);
  if (!parts.length) return source;
  let current = source;
  for (const part of parts) {
    if (!current || typeof current !== "object") return undefined;
    current = current[part];
  }
  return current;
}

function setByPath(target, path, value) {
  const parts = splitPath(path);
  if (!parts.length) return;
  let current = target;
  for (let i = 0; i < parts.length - 1; i += 1) {
    const key = parts[i];
    if (!current[key] || typeof current[key] !== "object" || Array.isArray(current[key])) {
      current[key] = {};
    }
    current = current[key];
  }
  current[parts[parts.length - 1]] = value;
}

function unsetByPath(target, path) {
  const parts = splitPath(path);
  if (!parts.length) return;
  let current = target;
  for (let i = 0; i < parts.length - 1; i += 1) {
    const key = parts[i];
    if (!current || typeof current !== "object") return;
    current = current[key];
  }
  if (!current || typeof current !== "object") return;
  delete current[parts[parts.length - 1]];
}

function compareValues(a, b) {
  const left = normalizeScalar(a);
  const right = normalizeScalar(b);
  if (left instanceof Date && right instanceof Date) {
    return left.getTime() - right.getTime();
  }
  if (left instanceof Date) {
    return left.getTime() - new Date(right).getTime();
  }
  if (right instanceof Date) {
    return new Date(left).getTime() - right.getTime();
  }
  if (typeof left === "number" && typeof right === "number") {
    return left - right;
  }
  return String(left).localeCompare(String(right));
}

function equalsValue(a, b) {
  const left = normalizeScalar(a);
  const right = normalizeScalar(b);
  if (left instanceof Date && right instanceof Date) {
    return left.getTime() === right.getTime();
  }
  if (left instanceof Date || right instanceof Date) {
    return compareValues(left, right) === 0;
  }
  if (Array.isArray(left) && Array.isArray(right)) {
    if (left.length !== right.length) return false;
    return left.every((item, index) => equalsValue(item, right[index]));
  }
  if (isPlainObject(left) && isPlainObject(right)) {
    const leftKeys = Object.keys(left);
    const rightKeys = Object.keys(right);
    if (leftKeys.length !== rightKeys.length) return false;
    return leftKeys.every((key) => equalsValue(left[key], right[key]));
  }
  return left === right;
}

function arrayContainsValue(arrayValue, expected) {
  if (!Array.isArray(arrayValue)) return false;
  return arrayValue.some((entry) => equalsValue(entry, expected));
}

function toComparablePrimitive(value) {
  const normalized = normalizeScalar(value);
  if (normalized instanceof Date) return normalized.getTime();
  if (typeof normalized === "number") return normalized;
  if (typeof normalized === "boolean") return normalized ? 1 : 0;
  if (normalized == null) return null;
  return String(normalized);
}

function matchesOperator(fieldValue, operator, expected) {
  if (operator === "$in") {
    const expectedValues = Array.isArray(expected) ? expected : [expected];
    if (Array.isArray(fieldValue)) {
      return fieldValue.some((item) =>
        expectedValues.some((candidate) => equalsValue(item, candidate))
      );
    }
    return expectedValues.some((candidate) => equalsValue(fieldValue, candidate));
  }

  if (operator === "$ne") {
    return !equalsValue(fieldValue, expected);
  }

  if (operator === "$exists") {
    const exists = typeof fieldValue !== "undefined";
    return Boolean(expected) ? exists : !exists;
  }

  if (operator === "$gte") {
    return toComparablePrimitive(fieldValue) >= toComparablePrimitive(expected);
  }
  if (operator === "$gt") {
    return toComparablePrimitive(fieldValue) > toComparablePrimitive(expected);
  }
  if (operator === "$lte") {
    return toComparablePrimitive(fieldValue) <= toComparablePrimitive(expected);
  }
  if (operator === "$lt") {
    return toComparablePrimitive(fieldValue) < toComparablePrimitive(expected);
  }

  if (operator === "$regex") {
    const source = Array.isArray(fieldValue)
      ? fieldValue.map((value) => String(value || "")).join(" ")
      : String(fieldValue || "");
    const flags = typeof expected?.flags === "string" ? expected.flags : "";
    const pattern = expected instanceof RegExp ? expected : new RegExp(String(expected || ""), flags);
    return pattern.test(source);
  }

  if (operator === "$size") {
    return Array.isArray(fieldValue) && fieldValue.length === Number(expected);
  }

  return false;
}

function matchesCondition(fieldValue, condition) {
  if (condition instanceof RegExp) {
    if (Array.isArray(fieldValue)) {
      return fieldValue.some((item) => condition.test(String(item || "")));
    }
    return condition.test(String(fieldValue || ""));
  }

  if (isPlainObject(condition)) {
    const operators = Object.keys(condition).filter((key) => key.startsWith("$"));
    if (operators.length) {
      if (operators.includes("$regex")) {
        const flags = typeof condition.$options === "string" ? condition.$options : "";
        const pattern =
          condition.$regex instanceof RegExp
            ? condition.$regex
            : new RegExp(String(condition.$regex || ""), flags);
        return matchesOperator(fieldValue, "$regex", pattern);
      }

      return operators.every((operator) =>
        operator === "$options"
          ? true
          :
        matchesOperator(fieldValue, operator, condition[operator])
      );
    }
  }

  if (Array.isArray(fieldValue) && !Array.isArray(condition)) {
    return arrayContainsValue(fieldValue, condition);
  }

  return equalsValue(fieldValue, condition);
}

function flattenText(value) {
  if (value == null) return "";
  if (typeof value === "string") return value;
  if (typeof value === "number" || typeof value === "boolean") return String(value);
  if (value instanceof Date) return value.toISOString();
  if (Array.isArray(value)) return value.map((item) => flattenText(item)).join(" ");
  if (isPlainObject(value)) return Object.values(value).map((item) => flattenText(item)).join(" ");
  return "";
}

function matchesFilter(doc, filter = {}) {
  if (!filter || !isPlainObject(filter) || !Object.keys(filter).length) return true;

  if (Array.isArray(filter.$and)) {
    const andOk = filter.$and.every((item) => matchesFilter(doc, item));
    if (!andOk) return false;
  }

  if (Array.isArray(filter.$or)) {
    const orOk = filter.$or.some((item) => matchesFilter(doc, item));
    if (!orOk) return false;
  }

  for (const [key, condition] of Object.entries(filter)) {
    if (key === "$and" || key === "$or") continue;

    if (key === "$text") {
      const search = String(condition?.$search || "").trim().toLowerCase();
      if (!search) continue;
      const haystack = flattenText(doc).toLowerCase();
      if (!haystack.includes(search)) return false;
      continue;
    }

    const fieldValue = getByPath(doc, key);
    if (!matchesCondition(fieldValue, condition)) return false;
  }

  return true;
}

function sortDocs(items, sortSpec) {
  const entries = Object.entries(sortSpec || {});
  if (!entries.length) return items;

  return [...items].sort((a, b) => {
    for (const [key, dirRaw] of entries) {
      const dir = Number(dirRaw) >= 0 ? 1 : -1;
      const left = getByPath(a, key);
      const right = getByPath(b, key);
      const cmp = compareValues(left, right);
      if (cmp !== 0) return dir * cmp;
    }
    return 0;
  });
}

function isLikelyArrayField(path) {
  const normalizedPath = String(path || "").trim();
  if (!normalizedPath) return false;
  if (ARRAY_MEMBERSHIP_FIELDS.has(normalizedPath)) return true;
  const parts = splitPath(normalizedPath);
  const last = parts.length ? parts[parts.length - 1] : normalizedPath;
  return ARRAY_MEMBERSHIP_FIELDS.has(last);
}

function toFirestoreQueryValue(value) {
  const normalized = normalizeScalar(value);
  if (normalized instanceof Date) return normalized;
  if (normalized === null) return null;
  const valueType = typeof normalized;
  if (
    valueType === "string" ||
    valueType === "number" ||
    valueType === "boolean"
  ) {
    return normalized;
  }
  return undefined;
}

function uniqueQueryValues(values = []) {
  const seen = new Set();
  const out = [];

  for (const value of values) {
    const normalized = toFirestoreQueryValue(value);
    if (typeof normalized === "undefined") continue;
    const key =
      normalized instanceof Date
        ? `date:${normalized.getTime()}`
        : `${typeof normalized}:${String(normalized)}`;
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(normalized);
  }

  return out;
}

function parseFieldClauses(path, condition) {
  const field = String(path || "").trim();
  if (!field) {
    return { supported: false, reason: "empty field path" };
  }

  if (condition instanceof RegExp) {
    return { supported: false, reason: `regex is not queryable for ${field}` };
  }

  if (isPlainObject(condition)) {
    const operatorKeys = Object.keys(condition).filter((key) =>
      key.startsWith("$")
    );

    if (operatorKeys.length) {
      if (operatorKeys.includes("$regex")) {
        return {
          supported: false,
          reason: `regex operator is not queryable for ${field}`,
        };
      }

      const clauses = [];
      for (const operator of operatorKeys) {
        const rawValue = condition[operator];
        if (operator === "$options") {
          continue;
        }

        if (operator === "$in") {
          if (!Array.isArray(rawValue)) {
            return {
              supported: false,
              reason: `$in expects an array for ${field}`,
            };
          }

          const values = uniqueQueryValues(rawValue);
          const inOperator = isLikelyArrayField(field)
            ? "array-contains-any"
            : "in";
          clauses.push({ field, operator: inOperator, value: values });
          continue;
        }

        if (
          operator === "$gte" ||
          operator === "$gt" ||
          operator === "$lte" ||
          operator === "$lt" ||
          operator === "$ne"
        ) {
          const value = toFirestoreQueryValue(rawValue);
          if (typeof value === "undefined") {
            return {
              supported: false,
              reason: `unsupported value for ${operator} on ${field}`,
            };
          }
          clauses.push({ field, operator, value });
          continue;
        }

        if (operator === "$exists" || operator === "$size" || operator === "$text") {
          return {
            supported: false,
            reason: `${operator} is not queryable for ${field}`,
          };
        }

        return {
          supported: false,
          reason: `unsupported operator ${operator} for ${field}`,
        };
      }

      return { supported: true, clauses };
    }
  }

  const value = toFirestoreQueryValue(condition);
  if (typeof value === "undefined") {
    return {
      supported: false,
      reason: `unsupported equality value for ${field}`,
    };
  }

  if (isLikelyArrayField(field)) {
    return {
      supported: true,
      clauses: [{ field, operator: "array-contains", value }],
    };
  }

  return { supported: true, clauses: [{ field, operator: "eq", value }] };
}

function combineSpecLists(leftSpecs = [[]], rightSpecs = [[]]) {
  const out = [];
  for (const left of leftSpecs) {
    for (const right of rightSpecs) {
      out.push([...(left || []), ...(right || [])]);
    }
  }
  return out;
}

function parseFilterToFirestoreSpecs(filter = {}) {
  if (!filter || !isPlainObject(filter)) {
    return {
      supported: false,
      reason: "filter must be a plain object",
    };
  }

  let specs = [[]];

  for (const [key, condition] of Object.entries(filter)) {
    if (key === "$and") {
      if (!Array.isArray(condition)) {
        return { supported: false, reason: "$and must be an array" };
      }
      for (const part of condition) {
        const parsed = parseFilterToFirestoreSpecs(part || {});
        if (!parsed.supported) return parsed;
        specs = combineSpecLists(specs, parsed.specs);
        if (!specs.length) return { supported: true, specs: [] };
      }
      continue;
    }

    if (key === "$or") {
      if (!Array.isArray(condition)) {
        return { supported: false, reason: "$or must be an array" };
      }

      let orSpecs = [];
      for (const part of condition) {
        const parsed = parseFilterToFirestoreSpecs(part || {});
        if (!parsed.supported) return parsed;
        orSpecs = orSpecs.concat(parsed.specs || []);
      }

      if (!orSpecs.length) {
        return { supported: true, specs: [] };
      }

      specs = combineSpecLists(specs, orSpecs);
      if (!specs.length) return { supported: true, specs: [] };
      continue;
    }

    if (key === "$text") {
      return { supported: false, reason: "$text is not queryable" };
    }

    const parsedField = parseFieldClauses(key, condition);
    if (!parsedField.supported) return parsedField;

    specs = specs.map((existing) => existing.concat(parsedField.clauses || []));
    if (!specs.length) return { supported: true, specs: [] };
  }

  return { supported: true, specs };
}

function chunkArray(values = [], size = FIRESTORE_IN_LIMIT) {
  if (!Array.isArray(values) || !values.length) return [];
  const out = [];
  for (let i = 0; i < values.length; i += size) {
    out.push(values.slice(i, i + size));
  }
  return out;
}

function expandSpecsForInClauses(spec = []) {
  let specs = [spec];

  for (let index = 0; index < spec.length; index += 1) {
    const clause = spec[index];
    if (!clause) continue;
    if (clause.operator !== "in" && clause.operator !== "array-contains-any") {
      continue;
    }

    const values = uniqueQueryValues(Array.isArray(clause.value) ? clause.value : []);
    if (!values.length) {
      return [];
    }

    const chunks = chunkArray(values, FIRESTORE_IN_LIMIT);
    if (!chunks.length) {
      return [];
    }

    let nextSpecs = [];
    for (const currentSpec of specs) {
      for (const chunk of chunks) {
        const cloned = currentSpec.map((entry, entryIndex) =>
          entryIndex === index ? { ...entry, value: chunk } : entry
        );
        nextSpecs.push(cloned);
      }
    }
    specs = nextSpecs;
  }

  return specs;
}

function mapToFirestoreOperator(operator) {
  if (operator === "eq") return "==";
  if (operator === "$ne") return "!=";
  if (operator === "$gte") return ">=";
  if (operator === "$gt") return ">";
  if (operator === "$lte") return "<=";
  if (operator === "$lt") return "<";
  if (operator === "in") return "in";
  if (operator === "array-contains") return "array-contains";
  if (operator === "array-contains-any") return "array-contains-any";
  return null;
}

function applyFirestoreWhereClause(ref, clause) {
  const firestoreOperator = mapToFirestoreOperator(clause?.operator);
  if (!firestoreOperator) {
    throw new Error(`Unsupported Firestore operator: ${clause?.operator || "unknown"}`);
  }
  return ref.where(String(clause.field || ""), firestoreOperator, clause.value);
}

function filterSummary(filter) {
  try {
    const compact = JSON.stringify(filter);
    if (!compact) return "{}";
    return compact.length > 300 ? `${compact.slice(0, 300)}...` : compact;
  } catch {
    return "[unserializable-filter]";
  }
}

function parseProjection(projection) {
  if (!projection) return null;

  if (typeof projection === "string") {
    const parts = projection
      .split(/\s+/)
      .map((part) => part.trim())
      .filter(Boolean);
    if (!parts.length) return null;
    const include = parts.filter((part) => !part.startsWith("-"));
    const exclude = parts
      .filter((part) => part.startsWith("-"))
      .map((part) => part.slice(1));
    if (include.length) return { mode: "include", paths: include };
    if (exclude.length) return { mode: "exclude", paths: exclude };
    return null;
  }

  if (isPlainObject(projection)) {
    const include = [];
    const exclude = [];
    for (const [key, value] of Object.entries(projection)) {
      if (Number(value) === 1) include.push(key);
      else if (Number(value) === 0) exclude.push(key);
    }
    if (include.length) return { mode: "include", paths: include };
    if (exclude.length) return { mode: "exclude", paths: exclude };
  }

  return null;
}

function applyProjection(doc, projection) {
  const spec = parseProjection(projection);
  if (!spec) return deepClone(doc);

  if (spec.mode === "include") {
    const out = {};
    if (!spec.paths.includes("_id") && typeof doc._id !== "undefined") {
      out._id = doc._id;
    }
    for (const path of spec.paths) {
      if (path === "_id") {
        out._id = doc._id;
        continue;
      }
      const value = getByPath(doc, path);
      if (typeof value !== "undefined") {
        setByPath(out, path, deepClone(value));
      }
    }
    return out;
  }

  const out = deepClone(doc);
  for (const path of spec.paths) {
    if (path === "_id") continue;
    unsetByPath(out, path);
  }
  return out;
}

function normalizePopulateArg(pathOrObject, select) {
  if (!pathOrObject) return null;
  if (typeof pathOrObject === "string") {
    return { path: pathOrObject, select: select || null, match: null };
  }
  if (isPlainObject(pathOrObject) && pathOrObject.path) {
    return {
      path: String(pathOrObject.path),
      select: pathOrObject.select || null,
      match: pathOrObject.match || null,
    };
  }
  return null;
}

class FirestoreDocument {
  constructor(model, data = {}) {
    Object.defineProperty(this, "__model", {
      value: model,
      writable: true,
      configurable: true,
      enumerable: false,
    });
    Object.assign(this, deepClone(data));
  }

  toObject() {
    const out = {};
    for (const [key, value] of Object.entries(this)) {
      if (key === "__model") continue;
      out[key] = deepClone(value);
    }
    return out;
  }

  async save() {
    const saved = await this.__model._saveDocumentData(this.toObject());
    for (const key of Object.keys(this)) {
      delete this[key];
    }
    Object.assign(this, saved);
    return this;
  }

  async populate(pathOrObject, select) {
    const populateSpec = normalizePopulateArg(pathOrObject, select);
    if (!populateSpec) return this;
    const plain = this.toObject();
    const populated = await this.__model._applyPopulateToDoc(plain, [populateSpec]);
    for (const key of Object.keys(this)) {
      delete this[key];
    }
    Object.assign(this, populated);
    return this;
  }
}

class FindQuery {
  constructor(model, { filter = {}, projection = null, single = false } = {}) {
    this.model = model;
    this.filter = filter || {};
    this.projection = projection || null;
    this.single = single === true;
    this.sortSpec = null;
    this.skipCount = 0;
    this.limitCount = null;
    this.isLean = false;
    this.populates = [];
    this.selectSpec = null;
  }

  sort(spec) {
    this.sortSpec = spec || null;
    return this;
  }

  skip(count) {
    this.skipCount = Math.max(0, Number(count) || 0);
    return this;
  }

  limit(count) {
    const parsed = Number(count);
    this.limitCount = Number.isFinite(parsed) ? Math.max(0, parsed) : null;
    return this;
  }

  select(spec) {
    this.selectSpec = spec;
    return this;
  }

  lean() {
    this.isLean = true;
    return this;
  }

  populate(pathOrObject, select) {
    const populateSpec = normalizePopulateArg(pathOrObject, select);
    if (populateSpec) this.populates.push(populateSpec);
    return this;
  }

  async exec() {
    const findResult = await this.model._findPlainDocs(this.filter, {
      sortSpec: this.sortSpec,
      skipCount: this.skipCount,
      limitCount: this.limitCount,
      single: this.single,
      applyQueryOptions: true,
    });

    let docs = findResult.docs;
    const queryApplied = findResult.queryApplied || {};

    if (this.sortSpec && !queryApplied.sort) docs = sortDocs(docs, this.sortSpec);
    if (this.skipCount && !queryApplied.skip) docs = docs.slice(this.skipCount);
    if (this.limitCount !== null && !queryApplied.limit) {
      docs = docs.slice(0, this.limitCount);
    }

    const projectionToUse = this.selectSpec || this.projection;
    docs = docs.map((doc) => applyProjection(doc, projectionToUse));

    if (this.populates.length) {
      docs = await Promise.all(
        docs.map((doc) => this.model._applyPopulateToDoc(doc, this.populates))
      );
    }

    if (this.single) {
      const one = docs.length ? docs[0] : null;
      if (!one) return null;
      return this.isLean ? one : this.model._toDocument(one);
    }

    return this.isLean ? docs : docs.map((doc) => this.model._toDocument(doc));
  }

  then(onFulfilled, onRejected) {
    return this.exec().then(onFulfilled, onRejected);
  }

  catch(onRejected) {
    return this.exec().catch(onRejected);
  }

  finally(onFinally) {
    return this.exec().finally(onFinally);
  }
}

class SingleResultQuery {
  constructor(model, producer) {
    this.model = model;
    this.producer = producer;
    this.selectSpec = null;
    this.isLean = false;
    this.populates = [];
  }

  select(spec) {
    this.selectSpec = spec;
    return this;
  }

  lean() {
    this.isLean = true;
    return this;
  }

  populate(pathOrObject, select) {
    const populateSpec = normalizePopulateArg(pathOrObject, select);
    if (populateSpec) this.populates.push(populateSpec);
    return this;
  }

  async exec() {
    let doc = await this.producer();
    if (!doc) return null;

    doc = applyProjection(doc, this.selectSpec);

    if (this.populates.length) {
      doc = await this.model._applyPopulateToDoc(doc, this.populates);
    }

    return this.isLean ? doc : this.model._toDocument(doc);
  }

  then(onFulfilled, onRejected) {
    return this.exec().then(onFulfilled, onRejected);
  }

  catch(onRejected) {
    return this.exec().catch(onRejected);
  }

  finally(onFinally) {
    return this.exec().finally(onFinally);
  }
}

function applyUpdateObject(doc, update = {}) {
  const next = deepClone(doc || {});
  const hasOperator = Object.keys(update).some((key) => key.startsWith("$"));

  if (!hasOperator) {
    for (const [key, value] of Object.entries(update)) {
      if (value === undefined) unsetByPath(next, key);
      else setByPath(next, key, deepClone(normalizeScalar(value)));
    }
    return next;
  }

  if (isPlainObject(update.$set)) {
    for (const [path, value] of Object.entries(update.$set)) {
      if (value === undefined) unsetByPath(next, path);
      else setByPath(next, path, deepClone(normalizeScalar(value)));
    }
  }

  if (isPlainObject(update.$unset)) {
    for (const path of Object.keys(update.$unset)) {
      unsetByPath(next, path);
    }
  }

  if (isPlainObject(update.$inc)) {
    for (const [path, deltaValue] of Object.entries(update.$inc)) {
      const delta = Number(deltaValue || 0);
      const current = Number(getByPath(next, path) || 0);
      setByPath(next, path, current + delta);
    }
  }

  if (isPlainObject(update.$addToSet)) {
    for (const [path, value] of Object.entries(update.$addToSet)) {
      const existing = getByPath(next, path);
      const base = Array.isArray(existing) ? [...existing] : [];

      const pushIfMissing = (candidate) => {
        if (!base.some((entry) => equalsValue(entry, candidate))) {
          base.push(candidate);
        }
      };

      if (isPlainObject(value) && Array.isArray(value.$each)) {
        value.$each.forEach((item) => pushIfMissing(normalizeScalar(item)));
      } else {
        pushIfMissing(normalizeScalar(value));
      }

      setByPath(next, path, base);
    }
  }

  if (isPlainObject(update.$pull)) {
    for (const [path, value] of Object.entries(update.$pull)) {
      const existing = getByPath(next, path);
      if (!Array.isArray(existing)) continue;
      const filtered = existing.filter((entry) => !equalsValue(entry, value));
      setByPath(next, path, filtered);
    }
  }

  return next;
}

function generateHexId() {
  return crypto.randomBytes(12).toString("hex");
}

function registerModel(modelName, model) {
  MODEL_REGISTRY.set(modelName, model);
}

function getRegisteredModel(modelName) {
  return MODEL_REGISTRY.get(modelName) || null;
}

function createFirestoreModel({
  modelName,
  collectionName,
  refs = {},
  defaults = {},
  beforeSave = null,
  instanceMethods = {},
  staticMethods = {},
} = {}) {
  if (!modelName || !collectionName) {
    throw new Error("modelName and collectionName are required for Firestore models.");
  }

  class Model extends FirestoreDocument {
    constructor(data = {}, fromStore = false) {
      const baseDefaults =
        typeof defaults === "function" ? defaults() : deepClone(defaults || {});
      const prepared = fromStore ? deepClone(data || {}) : { ...baseDefaults, ...deepClone(data || {}) };
      super(Model, prepared);
    }

    static get modelName() {
      return modelName;
    }

    static get collectionName() {
      return collectionName;
    }

    static _toDocument(data = {}) {
      return new Model(data, true);
    }

    static _db() {
      return getFirestore();
    }

    static _collection() {
      return this._db().collection(collectionName);
    }

    static _normalizeId(value) {
      const normalized = toObjectIdString(value || "").trim();
      return normalized || "";
    }

    static _hydrateDoc(data, fallbackId) {
      const hydrated = hydrateFromStorage(data || {});
      const id = this._normalizeId(hydrated._id || fallbackId || "");
      return {
        ...hydrated,
        _id: id,
      };
    }

    static async _readById(id) {
      const normalizedId = this._normalizeId(id);
      if (!normalizedId) return null;
      const snap = await this._collection().doc(normalizedId).get();
      if (!snap.exists) return null;
      return this._hydrateDoc(snap.data() || {}, normalizedId);
    }

    static _applyBeforeSave(doc, context) {
      if (typeof beforeSave === "function") {
        return beforeSave(deepClone(doc), context) || doc;
      }
      return doc;
    }

    static async _saveDocumentData(data = {}) {
      const raw = deepClone(data || {});
      const normalizedId = this._normalizeId(raw._id || generateHexId());

      const existing = await this._readById(normalizedId);
      const creating = !existing;
      const now = new Date();

      const baseDefaults =
        typeof defaults === "function" ? defaults() : deepClone(defaults || {});
      const merged = creating
        ? { ...baseDefaults, ...raw }
        : { ...existing, ...raw };

      merged._id = normalizedId;
      if (!merged.createdAt) merged.createdAt = now;
      merged.updatedAt = now;

      const prepared = this._applyBeforeSave(merged, {
        creating,
        existing,
      });

      const payload = sanitizeForStorage(prepared);
      payload._id = normalizedId;

      await this._collection().doc(normalizedId).set(payload, { merge: false });
      return this._hydrateDoc(payload, normalizedId);
    }

    static async _findPlainDocs(filter = {}, queryOptions = {}) {
      const normalizedFilter = isPlainObject(filter) ? filter : {};
      const options = {
        sortSpec: null,
        skipCount: 0,
        limitCount: null,
        single: false,
        applyQueryOptions: false,
        ...queryOptions,
      };

      const queryApplied = { sort: false, skip: false, limit: false };

      const scanFallback = async (reason) => {
        if (ENABLE_SCAN_FALLBACK_LOG) {
          console.warn(
            `[firestoreModel:${modelName}] full-scan fallback on ${collectionName}: ${reason}; filter=${filterSummary(normalizedFilter)}`
          );
        }
        const snapshot = await this._collection().get();
        const docs = snapshot.docs
          .map((docSnap) => this._hydrateDoc(docSnap.data() || {}, docSnap.id))
          .filter((doc) => matchesFilter(doc, normalizedFilter));
        return { docs, queryApplied };
      };

      const parsed = parseFilterToFirestoreSpecs(normalizedFilter);
      if (!parsed.supported) {
        return scanFallback(parsed.reason || "unsupported filter");
      }

      if (!Array.isArray(parsed.specs) || !parsed.specs.length) {
        return { docs: [], queryApplied };
      }

      let specs = [];
      for (const baseSpec of parsed.specs) {
        const expanded = expandSpecsForInClauses(baseSpec);
        if (!expanded.length) continue;
        specs = specs.concat(expanded);
      }

      if (!specs.length) {
        return { docs: [], queryApplied };
      }

      const allowQueryModifiers =
        options.applyQueryOptions === true && specs.length === 1;
      const docsById = new Map();
      const idReadCache = new Map();

      for (const spec of specs) {
        const idEqClauses = spec.filter(
          (clause) => clause?.field === "_id" && clause?.operator === "eq"
        );
        const idInClauses = spec.filter(
          (clause) =>
            clause?.field === "_id" &&
            (clause?.operator === "in" ||
              clause?.operator === "array-contains-any")
        );
        const nonIdClauses = spec.filter((clause) => clause?.field !== "_id");

        let docsForSpec = [];

        if (idEqClauses.length || idInClauses.length) {
          const candidateIds = uniqueQueryValues([
            ...idEqClauses.map((clause) => clause.value),
            ...idInClauses.flatMap((clause) =>
              Array.isArray(clause.value) ? clause.value : []
            ),
          ])
            .map((value) => this._normalizeId(value))
            .filter(Boolean);

          for (const id of candidateIds) {
            if (!idReadCache.has(id)) {
              const doc = await this._readById(id);
              idReadCache.set(id, doc || null);
            }
            const cached = idReadCache.get(id);
            if (cached) docsForSpec.push(cached);
          }
        } else {
          let ref = this._collection();
          try {
            for (const clause of nonIdClauses) {
              ref = applyFirestoreWhereClause(ref, clause);
            }

            if (allowQueryModifiers && isPlainObject(options.sortSpec)) {
              for (const [field, directionRaw] of Object.entries(options.sortSpec)) {
                const direction = Number(directionRaw) >= 0 ? "asc" : "desc";
                ref = ref.orderBy(String(field), direction);
              }
              if (Object.keys(options.sortSpec).length) {
                queryApplied.sort = true;
              }
            }

            if (allowQueryModifiers && Number(options.skipCount) > 0) {
              ref = ref.offset(Math.max(0, Number(options.skipCount) || 0));
              queryApplied.skip = true;
            }

            const hasExplicitLimit =
              options.limitCount !== null &&
              typeof options.limitCount !== "undefined";
            if (allowQueryModifiers && hasExplicitLimit) {
              const limit = Math.max(0, Number(options.limitCount) || 0);
              ref = ref.limit(limit);
              queryApplied.limit = true;
            } else if (allowQueryModifiers && options.single) {
              ref = ref.limit(1);
              queryApplied.limit = true;
            } else if (options.single) {
              if (
                isPlainObject(options.sortSpec) &&
                Object.keys(options.sortSpec).length
              ) {
                for (const [field, directionRaw] of Object.entries(options.sortSpec)) {
                  const direction = Number(directionRaw) >= 0 ? "asc" : "desc";
                  ref = ref.orderBy(String(field), direction);
                }
              }
              ref = ref.limit(1);
            }

            const snapshot = await ref.get();
            docsForSpec = snapshot.docs.map((docSnap) =>
              this._hydrateDoc(docSnap.data() || {}, docSnap.id)
            );
          } catch (err) {
            return scanFallback(err?.message || "query execution failed");
          }
        }

        for (const doc of docsForSpec) {
          if (!doc?._id) continue;
          docsById.set(doc._id, doc);
        }
      }

      const docs = Array.from(docsById.values()).filter((doc) =>
        matchesFilter(doc, normalizedFilter)
      );
      return { docs, queryApplied };
    }

    static async _applyPopulateToDoc(doc, populates = []) {
      let out = deepClone(doc);
      for (const populate of populates) {
        const path = populate?.path;
        if (!path) continue;
        const targetModelName = refs[path];
        if (!targetModelName) continue;
        const targetModel = getRegisteredModel(targetModelName);
        if (!targetModel) continue;

        const currentValue = getByPath(out, path);
        if (Array.isArray(currentValue)) {
          const populated = [];
          for (const rawId of currentValue) {
            const normalizedId =
              rawId && typeof rawId === "object" && rawId._id
                ? rawId._id
                : rawId;
            const found = await targetModel._readById(normalizedId);
            if (!found) continue;
            if (populate.match && !matchesFilter(found, populate.match)) continue;
            const projected = populate.select
              ? applyProjection(found, populate.select)
              : found;
            populated.push(projected);
          }
          setByPath(out, path, populated);
        } else {
          const normalizedId =
            currentValue && typeof currentValue === "object" && currentValue._id
              ? currentValue._id
              : currentValue;
          const found = await targetModel._readById(normalizedId);
          if (!found) {
            setByPath(out, path, null);
            continue;
          }
          if (populate.match && !matchesFilter(found, populate.match)) {
            setByPath(out, path, null);
            continue;
          }
          const projected = populate.select
            ? applyProjection(found, populate.select)
            : found;
          setByPath(out, path, projected);
        }
      }
      return out;
    }

    static find(filter = {}, projection = null) {
      return new FindQuery(this, {
        filter: filter || {},
        projection,
        single: false,
      });
    }

    static findOne(filter = {}, projection = null) {
      return new FindQuery(this, {
        filter: filter || {},
        projection,
        single: true,
      });
    }

    static findById(id, projection = null) {
      const producer = async () => {
        const doc = await this._readById(id);
        return doc ? deepClone(doc) : null;
      };
      const query = new SingleResultQuery(this, producer);
      if (projection) query.select(projection);
      return query;
    }

    static async create(data = {}) {
      const saved = await this._saveDocumentData(data);
      return this._toDocument(saved);
    }

    static _makeSingleWriteQuery(producer) {
      return new SingleResultQuery(this, producer);
    }

    static findByIdAndUpdate(id, update = {}, options = {}) {
      return this._makeSingleWriteQuery(async () => {
        const normalizedId = this._normalizeId(id);
        if (!normalizedId) return null;

        const existing = await this._readById(normalizedId);
        if (!existing && !options.upsert) return null;

        const base = existing || { _id: normalizedId };
        const previous = deepClone(base);
        const updated = applyUpdateObject(base, update);
        updated._id = normalizedId;

        const saved = await this._saveDocumentData(updated);
        return options.new ? saved : previous;
      });
    }

    static findOneAndUpdate(filter = {}, update = {}, options = {}) {
      return this._makeSingleWriteQuery(async () => {
        const findResult = await this._findPlainDocs(filter || {});
        const docs = findResult.docs;
        const target = docs[0] || null;

        if (!target && !options.upsert) return null;

        const id = target?._id || this._normalizeId(generateHexId());
        const previous = deepClone(target || null);
        const base = target || { _id: id };
        const updated = applyUpdateObject(base, update);
        updated._id = id;

        const saved = await this._saveDocumentData(updated);
        return options.new ? saved : previous;
      });
    }

    static async updateOne(filter = {}, update = {}) {
      const findResult = await this._findPlainDocs(filter || {});
      const docs = findResult.docs;
      const target = docs[0] || null;
      if (!target) return { acknowledged: true, matchedCount: 0, modifiedCount: 0 };

      const updated = applyUpdateObject(target, update);
      updated._id = target._id;
      await this._saveDocumentData(updated);
      return { acknowledged: true, matchedCount: 1, modifiedCount: 1 };
    }

    static async updateMany(filter = {}, update = {}) {
      const findResult = await this._findPlainDocs(filter || {});
      const docs = findResult.docs;
      if (!docs.length) {
        return { acknowledged: true, matchedCount: 0, modifiedCount: 0 };
      }
      for (const target of docs) {
        const updated = applyUpdateObject(target, update);
        updated._id = target._id;
        await this._saveDocumentData(updated);
      }
      return {
        acknowledged: true,
        matchedCount: docs.length,
        modifiedCount: docs.length,
      };
    }

    static deleteOne(filter = {}) {
      return Promise.resolve()
        .then(async () => {
          const findResult = await this._findPlainDocs(filter || {});
          const docs = findResult.docs;
          const target = docs[0] || null;
          if (!target) return { acknowledged: true, deletedCount: 0 };
          await this._collection().doc(target._id).delete();
          return { acknowledged: true, deletedCount: 1 };
        });
    }

    static async deleteMany(filter = {}) {
      const findResult = await this._findPlainDocs(filter || {});
      const docs = findResult.docs;
      for (const target of docs) {
        await this._collection().doc(target._id).delete();
      }
      return { acknowledged: true, deletedCount: docs.length };
    }

    static findByIdAndDelete(id) {
      return this._makeSingleWriteQuery(async () => {
        const existing = await this._readById(id);
        if (!existing) return null;
        await this._collection().doc(existing._id).delete();
        return existing;
      });
    }

    static async countDocuments(filter = {}) {
      const normalizedFilter = isPlainObject(filter) ? filter : {};
      const parsed = parseFilterToFirestoreSpecs(normalizedFilter);

      if (
        parsed.supported &&
        Array.isArray(parsed.specs) &&
        parsed.specs.length === 1
      ) {
        const expanded = expandSpecsForInClauses(parsed.specs[0] || []);
        if (!expanded.length) {
          return 0;
        }

        if (expanded.length === 1) {
          const spec = expanded[0];
          const idEqClauses = spec.filter(
            (clause) => clause?.field === "_id" && clause?.operator === "eq"
          );
          const idInClauses = spec.filter(
            (clause) =>
              clause?.field === "_id" &&
              (clause?.operator === "in" ||
                clause?.operator === "array-contains-any")
          );
          const nonIdClauses = spec.filter((clause) => clause?.field !== "_id");

          if (idEqClauses.length || idInClauses.length) {
            const candidateIds = uniqueQueryValues([
              ...idEqClauses.map((clause) => clause.value),
              ...idInClauses.flatMap((clause) =>
                Array.isArray(clause.value) ? clause.value : []
              ),
            ])
              .map((value) => this._normalizeId(value))
              .filter(Boolean);

            let total = 0;
            for (const id of candidateIds) {
              const doc = await this._readById(id);
              if (doc && matchesFilter(doc, normalizedFilter)) {
                total += 1;
              }
            }
            return total;
          }

          let ref = this._collection();
          try {
            for (const clause of nonIdClauses) {
              ref = applyFirestoreWhereClause(ref, clause);
            }
            if (typeof ref.count === "function") {
              const countSnap = await ref.count().get();
              return Number(countSnap?.data?.()?.count || 0);
            }
            const snapshot = await ref.get();
            return Number(snapshot?.size || 0);
          } catch {
            // fallback below
          }
        }
      }

      const findResult = await this._findPlainDocs(normalizedFilter);
      return findResult.docs.length;
    }

    static async exists(filter = {}) {
      const findResult = await this._findPlainDocs(filter || {}, {
        single: true,
        limitCount: 1,
        applyQueryOptions: true,
      });
      const docs = findResult.docs;
      if (!docs.length) return null;
      return { _id: docs[0]._id };
    }

    static async syncIndexes() {
      return [];
    }
  }

  for (const [name, fn] of Object.entries(instanceMethods || {})) {
    if (typeof fn === "function") {
      Model.prototype[name] = fn;
    }
  }

  for (const [name, fn] of Object.entries(staticMethods || {})) {
    if (typeof fn === "function") {
      Model[name] = fn.bind(Model);
    }
  }

  registerModel(modelName, Model);
  return Model;
}

module.exports = {
  createFirestoreModel,
  matchesFilter,
  getByPath,
  setByPath,
  unsetByPath,
  applyProjection,
};
