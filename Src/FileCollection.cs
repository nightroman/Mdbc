
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using MongoDB.Bson;
using MongoDB.Bson.IO;
using MongoDB.Bson.Serialization;
using MongoDB.Bson.Serialization.Options;
using MongoDB.Bson.Serialization.Serializers;
using MongoDB.Driver;

namespace Mdbc
{
    abstract class FileCollection : ICollectionHost
    {
        protected readonly string FilePath;
        protected readonly FileFormat FileFormat;
        internal abstract void Read(bool newCollection);
        protected abstract IList<BsonDocument> Documents { get; }
        protected abstract void InsertInternal(BsonDocument document);
        protected abstract void RemoveDocument(BsonDocument document);
        protected abstract void RemoveDocumentAt(int index);
        protected abstract void UpdateDocument(BsonDocument document, Func<BsonDocument, UpdateCompiler> update);
        protected virtual IDictionary<BsonValue, BsonDocument> Documents2 { get { return null; } }
        protected FileCollection(string path, FileFormat format)
        {
            FilePath = string.IsNullOrEmpty(path) ? null : path;
            FileFormat = format;
        }
        #region Collection
        public object Collection { get { return this; } }
        public long Count()
        {
            return (long)Documents.Count;
        }
        public long Count(IMongoQuery query)
        {
            return (long)(query == null ? Documents.Count : QueryDocuments(query).Count());
        }
        public long Count(IMongoQuery query, int skip, int first)
        {
            return FindAs(typeof(BsonDocument), query, QueryFlags.None, null, skip, first, null).Count();
        }
        public IEnumerable<BsonValue> Distinct(string key, IMongoQuery query)
        {
            //_131119_113717 Use the custom comparer strictly based on CompareTo.
            return QueryDocuments(query).Select(x => x[key]).Distinct(new BsonValueCompareToEqualityComparer());
        }
        public IEnumerable<object> FindAs(Type documentType, IMongoQuery query, QueryFlags modes, IMongoSortBy sortBy, int skip, int first, IMongoFields fields)
        {
            var iter = QueryCompiler.Query(Documents, Documents2, query, sortBy, skip, first);
            if (fields == null)
                return iter.Select(x => BsonSerializer.Deserialize(x, documentType));

            var project = FieldCompiler.GetFunction(fields);
            return iter.Select(project).Select(x => BsonSerializer.Deserialize(x, documentType));
        }
        public object FindAndModifyAs(Type documentType, IMongoQuery query, IMongoSortBy sortBy, IMongoUpdate update, IMongoFields fields, bool returnNew, bool upsert, out UpdateResult result)
        {
            foreach (var document in QueryCompiler.Query(Documents, Documents2, query, sortBy, 0, 0))
            {
                // if old is needed then deep(!) clone before update //_131103_185751
                BsonDocument output = null;
                if (!returnNew)
                    output = document.DeepClone().AsBsonDocument;

                UpdateDocument(document, UpdateCompiler.GetFunction((IConvertibleToBsonDocument)update, null, false));

                if (returnNew)
                    output = document;

                // project
                if (fields != null)
                {
                    var project = FieldCompiler.GetFunction(fields);
                    output = project(output);
                }

                // if old is needed then return it as already deep cloned
                result = new SimpleUpdateResult(1, true);
                if (!returnNew && documentType == typeof(Dictionary))
                    return new Dictionary(output);
                else
                    // deserialize to required type
                    return BsonSerializer.Deserialize(output, documentType);
            }

            // not found, insert
            if (upsert)
            {
                var document = InsertNewDocument(query, update);

                result = new SimpleUpdateResult(1, false);
                return returnNew ? BsonSerializer.Deserialize(document, documentType) : null;
            }

            result = new SimpleUpdateResult(0, false);
            return null;
        }
        public object FindAndRemoveAs(Type documentType, IMongoQuery query, IMongoSortBy sortBy)
        {
            foreach (var document in QueryCompiler.Query(Documents, Documents2, query, sortBy, 0, 0))
            {
                RemoveDocument(document);
                return BsonSerializer.Deserialize(document, documentType);
            }

            return null;
        }
        public virtual WriteConcernResult Save(BsonDocument document, WriteConcern writeConcern, bool needResult)
        {
            throw new NotSupportedException("Update-or-insert is not supported by simple collections.");
        }
        public WriteConcernResult Insert(BsonDocument document, WriteConcern writeConcern, bool needResult)
        {
            try
            {
                InsertInternal(CloneExternalDocument(document));

                return needResult ? new WriteConcernResult(NewResponse(0, false, null, null)) : null;
            }
            catch (Exception ex)
            {
                throw new FileWriteConcernException(ex.Message, new WriteConcernResult(NewResponse(0, false, ex.Message, null)));
            }
        }
        public WriteConcernResult Remove(IMongoQuery query, RemoveFlags flags, WriteConcern writeConcern, bool needResult)
        {
            var predicate = QueryCompiler.GetFunction(query.ToBsonDocument());

            int documentsAffected = 0;

            for (int i = 0; i < Documents.Count; ++i)
            {
                if (!predicate(Documents[i]))
                    continue;

                RemoveDocumentAt(i);

                ++documentsAffected;

                if ((flags & RemoveFlags.Single) > 0)
                    break;

                --i;
            }

            return needResult ? new WriteConcernResult(NewResponse(documentsAffected, false, null, null)) : null;
        }
        public WriteConcernResult Update(IMongoQuery query, IMongoUpdate update, UpdateFlags flags, WriteConcern writeConcern, bool needResult)
        {
            bool updatedExisting = false;
            int documentsAffected = 0;
            try
            {
                Func<BsonDocument, UpdateCompiler> function = null;
                foreach (var document in QueryDocuments(query))
                {
                    if (function == null)
                        function = UpdateCompiler.GetFunction((IConvertibleToBsonDocument)update, null, false);

                    UpdateDocument(document, function);

                    updatedExisting = true;
                    ++documentsAffected;

                    if ((flags & UpdateFlags.Multi) == 0)
                        break;
                }

                // not found and upsert
                if (function == null && (flags & UpdateFlags.Upsert) > 0)
                {
                    InsertNewDocument(query, update);
                    ++documentsAffected;
                }

                return needResult ? new WriteConcernResult(NewResponse(documentsAffected, updatedExisting, null, null)) : null;
            }
            catch (Exception ex)
            {
                throw new FileWriteConcernException(ex.Message, new WriteConcernResult(NewResponse(documentsAffected, updatedExisting, ex.Message, null)));
            }
        }
        #endregion
        protected static BsonDocument NewResponse(int documentsAffected, bool updatedExisting, string lastErrorMessage, string errorMessage)
        {
            var r = new BsonDocument();

            if (lastErrorMessage != null)
                r.Add("err", lastErrorMessage);

            if (updatedExisting)
                r.Add("updatedExisting", true);

            r.Add("n", documentsAffected);

            if (errorMessage != null)
                r.Add("errmsg", errorMessage);

            r.Add("ok", errorMessage == null);
            return r;
        }
        // Inserts a new document created from a query and an update and returns it.
        BsonDocument InsertNewDocument(IMongoQuery query, IMongoUpdate update)
        {
            var document = new BsonDocument();
            UpdateCompiler.GetFunction((IConvertibleToBsonDocument)update, query.ToBsonDocument(), true)(document);
            InsertInternal(document);
            return document;
        }
        protected static BsonDocument CloneExternalDocument(BsonDocument externalDocument)
        {
            var internalDocument = new BsonDocument();
            using (var writer = new BsonDocumentWriter(internalDocument))
            {
                //??writer.CheckElementNames = true;
                BsonSerializer.Serialize(writer, externalDocument);
            }
            return internalDocument;
        }
        IEnumerable<BsonDocument> QueryDocuments(IMongoQuery query)
        {
            return Documents.Where(QueryCompiler.GetFunction(query.ToBsonDocument()));
        }
        internal static IEnumerable<object> ReadDocumentsAs(Type documentType, string filePath, FileFormat format)
        {
            if (format == FileFormat.Auto)
                format = filePath.EndsWith(".json", StringComparison.OrdinalIgnoreCase) ? FileFormat.Json : FileFormat.Bson;

            var serializer = BsonSerializer.LookupSerializer(documentType);
            var args = new BsonDeserializationArgs();
            args.NominalType = documentType;

            if (format == FileFormat.Json)
            {
                using (var stream = File.OpenText(filePath))
                {
                    using (var reader = new JsonReader(stream))
                    {
                        var context = BsonDeserializationContext.CreateRoot(reader);
                        while (!reader.IsAtEndOfFile())
                            yield return serializer.Deserialize(context, args);
                    }
                }
            }
            else
            {
                using (var stream = File.OpenRead(filePath))
                {
                    long length = stream.Length;

                    while (stream.Position < length)
                        using (var reader = new BsonBinaryReader(stream))
                        {
                            var context = BsonDeserializationContext.CreateRoot(reader);
                            yield return serializer.Deserialize(context, args);
                        }
                }
            }
        }
        internal void Save(string saveAs, FileFormat format)
        {
            if (string.IsNullOrEmpty(saveAs))
            {
                saveAs = FilePath;
                format = FileFormat;
            }

            if (saveAs == null)
                throw new InvalidOperationException("File path should be provided either on opening or saving.");

            if (format == FileFormat.Auto)
                format = saveAs.EndsWith(".json", StringComparison.OrdinalIgnoreCase) ? FileFormat.Json : FileFormat.Bson;

            var tmp = File.Exists(saveAs) ? saveAs + ".tmp" : saveAs;

            var serializer = new BsonDocumentSerializer();
            var args = new BsonSerializationArgs();
            args.NominalType = typeof(BsonDocument);

            if (format == FileFormat.Json)
            {
                //?? try loop inside out
                using (var streamWriter = new StreamWriter(tmp))
                {
                    foreach (var document in Documents)
                    {
                        using (var stringWriter = new StringWriter(CultureInfo.InvariantCulture))
                        using (var jsonWriter = new JsonWriter(stringWriter, Actor.DefaultJsonWriterSettings))
                        {
                            var context = BsonSerializationContext.CreateRoot(jsonWriter);
                            serializer.Serialize(context, args, document);
                            streamWriter.WriteLine(stringWriter.ToString());
                        }
                    }
                }
            }
            else
            {
                using (var fileStream = File.Open(tmp, FileMode.Create, FileAccess.Write, FileShare.None))
                using (var bsonWriter = new BsonBinaryWriter(fileStream))
                {
                    var context = BsonSerializationContext.CreateRoot(bsonWriter);
                    foreach (var document in Documents)
                        serializer.Serialize(context, args, document);
                }
            }

            if (!object.ReferenceEquals(tmp, saveAs))
                File.Replace(tmp, saveAs, null);
        }
    }

    class FileWriteConcernException : Exception //??
    {
        public WriteConcernResult WriteConcernResult { get; private set; }
        public FileWriteConcernException(string message, WriteConcernResult writeConcernResult) : base(message)
        {
            WriteConcernResult = writeConcernResult;
        }
    }
}
