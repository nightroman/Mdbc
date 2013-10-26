
/* Copyright 2011-2013 Roman Kuzmin
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Management.Automation;
using MongoDB.Bson;
using MongoDB.Bson.IO;
using MongoDB.Bson.Serialization;
using MongoDB.Driver;

namespace Mdbc
{
	sealed class NormalDataFile : DataFile
	{
		SortedList<BsonValue, BsonDocument> _data;
		protected override IList<BsonDocument> Documents { get { return _data.Values; } }
		internal NormalDataFile(string path) : base(path) { }
		static void ThrowIdExists(BsonValue id)
		{
			throw new InvalidOperationException(string.Format(null, "Document with _id {0} already exists.", id));
		}
		protected override void InsertInternal(BsonDocument document)
		{
			// make id, try to add
			var id = document.EnsureId();
			try
			{
				_data.Add(id, document);
			}
			catch (ArgumentException)
			{
				ThrowIdExists(id);
			}
		}
		internal override void SaveDocument(BsonDocument document)
		{
			// copy, make id, override
			document = CloneExternalDocument(document);
			_data[document.EnsureId()] = document;
		}
		protected override void RemoveDocument(BsonDocument document)
		{
			_data.Remove(document[MyValue.Id]);
		}
		protected override void RemoveDocumentAt(int index)
		{
			_data.RemoveAt(index);
		}
		protected override void UpdateDocument(BsonDocument document, Func<BsonDocument, UpdateCompiler> update)
		{
			var oldId = document[MyValue.Id];
			var copy = document.DeepClone();
			try
			{
				update(document);

				BsonValue newId;
				if (!document.TryGetValue(MyValue.Id, out newId) || !oldId.Equals(newId))
					throw new InvalidOperationException("Modification of _id is not allowed.");
			}
			catch
			{
				document.Clear();
				document.AddRange(copy.AsBsonDocument);
				throw;
			}
		}
		internal override void Read(bool newCollection)
		{
			_data = new SortedList<BsonValue, BsonDocument>();

			if (newCollection || FilePath == null || !File.Exists(FilePath))
				return;

			int index = -1;
			foreach (BsonDocument doc in GetDocumentsFromFileAs(typeof(BsonDocument), FilePath))
			{
				++index;
				BsonValue id;
				if (!doc.TryGetValue(MyValue.Id, out id))
					throw new InvalidDataException(string.Format(null, "The document at {0} has no _id.", index));

				try
				{
					_data.Add(id, doc);
				}
				catch (System.ArgumentException)
				{
					throw new InvalidDataException(string.Format(null, @"The document at {0} has not unique _id ""{1}"".", index, id));
				}
			}
		}
	}
	sealed class SimpleDataFile : DataFile
	{
		List<BsonDocument> _data;
		protected override IList<BsonDocument> Documents { get { return _data; } }
		internal SimpleDataFile(string path) : base(path) { }
		protected override void InsertInternal(BsonDocument document)
		{
			_data.Add(document);
		}
		internal override void SaveDocument(BsonDocument document)
		{
			throw new NotImplementedException();
		}
		protected override void RemoveDocument(BsonDocument document)
		{
			_data.Remove(document);
		}
		protected override void RemoveDocumentAt(int index)
		{
			_data.RemoveAt(index);
		}
		protected override void UpdateDocument(BsonDocument document, Func<BsonDocument, UpdateCompiler> update)
		{
			var copy = document.DeepClone();
			try
			{
				update(document);
			}
			catch
			{
				document.Clear();
				document.AddRange(copy.AsBsonDocument);
				throw;
			}
		}
		internal override void Read(bool newCollection)
		{
			_data = new List<BsonDocument>();

			if (newCollection || FilePath == null || !File.Exists(FilePath))
				return;

			foreach (BsonDocument doc in GetDocumentsFromFileAs(typeof(BsonDocument), FilePath))
				_data.Add(doc);
		}
	}
	abstract class DataFile
	{
		protected readonly string FilePath;
		internal abstract void Read(bool newCollection);
		protected abstract IList<BsonDocument> Documents { get; }
		protected abstract void InsertInternal(BsonDocument document);
		internal abstract void SaveDocument(BsonDocument document);
		protected abstract void RemoveDocument(BsonDocument document);
		protected abstract void RemoveDocumentAt(int index);
		protected abstract void UpdateDocument(BsonDocument document, Func<BsonDocument, UpdateCompiler> update);
		protected DataFile(string path)
		{
			FilePath = string.IsNullOrEmpty(path) ? null : path;
		}
		// Inserts an external document.
		internal void InsertDocument(BsonDocument document)
		{
			InsertInternal(CloneExternalDocument(document));
		}
		// Inserts a new document created from a query and an update and returns it.
		BsonDocument InsertNewDocument(IMongoQuery query, IMongoUpdate update)
		{
			var document = new BsonDocument();
			UpdateCompiler.GetFunction(update, query, true)(document);
			InsertInternal(document);
			return document;
		}
		protected static BsonDocument CloneExternalDocument(BsonDocument externalDocument)
		{
			var internalDocument = new BsonDocument();
			using (var writer = BsonWriter.Create(internalDocument))
			{
				writer.CheckElementNames = true;
				BsonSerializer.Serialize(writer, externalDocument);
			}
			return internalDocument;
		}
		internal static IEnumerable<object> GetDocumentsFromFileAs(Type documentType, string filePath)
		{
			using (var stream = File.OpenRead(filePath))
			{
				long length = stream.Length;

				while (stream.Position < length)
					using (var _reader = BsonReader.Create(stream))
						yield return BsonSerializer.Deserialize(_reader, documentType);
			}
		}
		IEnumerable<BsonDocument> QueryDocuments(IMongoQuery query)
		{
			return Documents.Where(QueryCompiler.GetFunction(query));
		}
		internal void Save(string saveAs)
		{
			if (string.IsNullOrEmpty(saveAs))
				saveAs = FilePath;

			if (saveAs == null)
				throw new InvalidOperationException("File path should be provided either on opening or saving.");

			var tmp = File.Exists(saveAs) ? saveAs + ".tmp" : saveAs;

			using (var stream = File.Open(tmp, FileMode.Create, FileAccess.Write, FileShare.None))
			using (var writer = BsonWriter.Create(stream))
			{
				foreach (var doc in Documents)
					BsonSerializer.Serialize(writer, doc);
			}

			if (!object.ReferenceEquals(tmp, saveAs))
				File.Replace(tmp, saveAs, null);
		}
		internal void Remove(IMongoQuery query, RemoveFlags flags)
		{
			var predicate = QueryCompiler.GetFunction(query);

			for (int i = 0; i < Documents.Count; ++i)
			{
				if (!predicate(Documents[i]))
					continue;

				RemoveDocumentAt(i);

				if ((flags & RemoveFlags.Single) > 0)
					return;

				--i;
			}
		}
		internal long Count(IMongoQuery query)
		{
			return (long)(query == null ? Documents.Count : QueryDocuments(query).Count());
		}
		internal IEnumerable<BsonValue> Distinct(string key, IMongoQuery query)
		{
			return QueryDocuments(query).Select(x => x[key]).Distinct(new BsonValueEqualityComparer());
		}
		internal IEnumerable<object> FindAs(Type documentType, IMongoQuery query, IMongoSortBy sortBy, int first, int skip, IMongoFields fields)
		{
			var iter = QueryCompiler.Query(Documents, query, sortBy, first, skip);
			if (fields == null)
				return iter.Select(x => BsonSerializer.Deserialize(x, documentType));

			var project = FieldCompiler.GetFunction(fields);
			return iter.Select(project).Select(x => BsonSerializer.Deserialize(x, documentType));
		}
		internal object FindAndRemoveAs(Type documentType, IMongoQuery query, IMongoSortBy sortBy)
		{
			foreach (var document in QueryCompiler.Query(Documents, query, sortBy, 0, 0))
			{
				RemoveDocument(document);
				return BsonSerializer.Deserialize(document, documentType);
			}

			return null;
		}
		internal object FindAndModifyAs(Type documentType, IMongoQuery query, IMongoSortBy sortBy, IMongoUpdate update, IMongoFields fields, bool returnNew, bool upsert)
		{
			foreach (var document in QueryCompiler.Query(Documents, query, sortBy, 0, 0))
			{
				// if return old deep(!) clone before update //_131103_185751
				BsonDocument result = null;
				if (!returnNew)
					result = document.DeepClone().AsBsonDocument;

				UpdateDocument(document, UpdateCompiler.GetFunction(update, null, false));

				if (returnNew)
					result = document;

				// project
				if (fields != null)
				{
					var project = FieldCompiler.GetFunction(fields);
					result = project(result);
				}

				// deserialize to required type
				//TODO Perf: old was alredy deep cloned, we can return it more effectively
				return BsonSerializer.Deserialize(result, documentType);
			}

			// not found, insert
			if (upsert)
			{
				var document = InsertNewDocument(query, update);
				if (returnNew)
					return BsonSerializer.Deserialize(document, documentType);
			}

			return null;
		}
		internal void Update(IMongoQuery query, IMongoUpdate update, UpdateFlags flags)
		{
			Func<BsonDocument, UpdateCompiler> function = null;
			foreach (var document in QueryDocuments(query))
			{
				if (function == null)
					function = UpdateCompiler.GetFunction(update, null, false);

				UpdateDocument(document, function);
				if ((flags & UpdateFlags.Multi) == 0)
					return;
			}

			// not found and upsert
			if (function == null && (flags & UpdateFlags.Upsert) > 0)
				InsertNewDocument(query, update);
		}
	}
}
