
// Copyright (c) 2011-2016 Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System;
using System.Collections.Generic;
using System.IO;
using MongoDB.Bson;

namespace Mdbc
{
	sealed class SimpleFileCollection : FileCollection
	{
		List<BsonDocument> _data;
		protected override IList<BsonDocument> Documents { get { return _data; } }
		internal SimpleFileCollection(string path, FileFormat format) : base(path, format) { }
		protected override void InsertInternal(BsonDocument document)
		{
			_data.Add(document);
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

			foreach (BsonDocument doc in ReadDocumentsAs(typeof(BsonDocument), FilePath, FileFormat))
				_data.Add(doc);
		}
	}
}
