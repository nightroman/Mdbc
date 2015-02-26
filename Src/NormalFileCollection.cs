
/* Copyright 2011-2015 Roman Kuzmin
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
using MongoDB.Bson;
using MongoDB.Driver;

namespace Mdbc
{
	sealed class NormalFileCollection : FileCollection
	{
		SortedList<BsonValue, BsonDocument> _data;
		protected override IList<BsonDocument> Documents { get { return _data.Values; } }
		protected override IDictionary<BsonValue, BsonDocument> Documents2 { get { return _data; } }
		internal NormalFileCollection(string path, FileFormat format) : base(path, format) { }
		static void ThrowIdExists(BsonValue id)
		{
			throw new InvalidOperationException(string.Format(null, "Duplicate _id {0}.", id));
		}
		protected override void InsertInternal(BsonDocument document)
		{
			// make id
			BsonValue id;
			if (!document.TryGetValue(MyValue.Id, out id))
				id = document.EnsureId();
			else if (id.BsonType == BsonType.Array)
				throw new InvalidOperationException("Can't use an array for _id.");

			// try to add
			try
			{
				_data.Add(id, document);
			}
			catch (ArgumentException)
			{
				ThrowIdExists(id);
			}
		}
		public override WriteConcernResult Save(BsonDocument document, WriteConcern writeConcern, bool needResult)
		{
			// copy, make id, override
			document = CloneExternalDocument(document);
			var id = document.EnsureId();
			bool updatedExisting = _data.ContainsKey(id);
			_data[id] = document;

			return needResult ? new WriteConcernResult(NewResponse(1, updatedExisting, null, null)) : null;
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
			//_131119_113717 SortedList with the default comparer is OK, unlike Distinct. Watch/test cases like 1 and 1.0, @{x=1} and @{x=1.0}, etc.
			_data = new SortedList<BsonValue, BsonDocument>();

			if (newCollection || FilePath == null || !File.Exists(FilePath))
				return;

			int index = -1;
			foreach (BsonDocument doc in ReadDocumentsAs(typeof(BsonDocument), FilePath, FileFormat))
			{
				++index;
				BsonValue id;
				if (!doc.TryGetValue(MyValue.Id, out id))
					throw new InvalidDataException(string.Format(null, "The document (index {0}) has no _id.", index));

				try
				{
					_data.Add(id, doc);
				}
				catch (System.ArgumentException)
				{
					throw new InvalidDataException(string.Format(null, @"The document (index {0}) has duplicate _id ""{1}"".", index, id));
				}
			}
		}
	}
}
