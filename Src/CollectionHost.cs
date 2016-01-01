
// Copyright (c) 2011-2016 Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System;
using System.Collections.Generic;
using MongoDB.Bson;
using MongoDB.Driver;

namespace Mdbc
{
	interface ICollectionHost
	{
		object Collection { get; }
		long Count();
		long Count(IMongoQuery query);
		long Count(IMongoQuery query, int skip, int first);
		IEnumerable<BsonValue> Distinct(string key, IMongoQuery query);
		IEnumerable<object> FindAs(Type documentType, IMongoQuery query, QueryFlags modes, IMongoSortBy sortBy, int skip, int first, IMongoFields fields);
		object FindAndModifyAs(Type documentType, IMongoQuery query, IMongoSortBy sortBy, IMongoUpdate update, IMongoFields fields, bool returnNew, bool upsert, out UpdateResult result);
		object FindAndRemoveAs(Type documentType, IMongoQuery query, IMongoSortBy sortBy);
		WriteConcernResult Insert(BsonDocument document, WriteConcern writeConcern, bool needResult);
		WriteConcernResult Save(BsonDocument document, WriteConcern writeConcern, bool needResult);
		WriteConcernResult Remove(IMongoQuery query, RemoveFlags flags, WriteConcern writeConcern, bool needResult);
		WriteConcernResult Update(IMongoQuery query, IMongoUpdate update, UpdateFlags flags, WriteConcern writeConcern, bool needResult);
	}
	class MongoCollectionHost : ICollectionHost
	{
		readonly MongoCollection _this;
		public MongoCollectionHost(MongoCollection collection)
		{
			_this = collection;
		}
		public object Collection
		{
			get { return _this; }
		}
		public long Count()
		{
			return _this.Count();
		}
		public long Count(IMongoQuery query)
		{
			return _this.Count(query);
		}
		public long Count(IMongoQuery query, int skip, int first)
		{
			var cursor = _this.FindAs(typeof(BsonDocument), query);

			if (skip > 0)
				cursor.SetSkip(skip);

			if (first > 0)
				cursor.SetLimit(first);

			return cursor.Size();
		}
		public IEnumerable<BsonValue> Distinct(string key, IMongoQuery query)
		{
			return _this.Distinct(key, query);
		}
		public IEnumerable<object> FindAs(Type documentType, IMongoQuery query, QueryFlags modes, IMongoSortBy sortBy, int skip, int first, IMongoFields fields)
		{
			var cursor = _this.FindAs(documentType, query);

			if (modes != QueryFlags.None)
				cursor.SetFlags(modes);

			if (skip > 0)
				cursor.SetSkip(skip);

			if (first > 0)
				cursor.SetLimit(first);

			if (sortBy != null)
				cursor.SetSortOrder(sortBy);

			if (fields != null)
				cursor.SetFields(fields);

			foreach (var it in cursor)
				yield return it;
		}
		public object FindAndModifyAs(Type documentType, IMongoQuery query, IMongoSortBy sortBy, IMongoUpdate update, IMongoFields fields, bool returnNew, bool upsert, out UpdateResult result)
		{
			var args = new FindAndModifyArgs();
			args.Query = query;
			args.SortBy = sortBy;
			args.Update = update;
			args.Fields = fields;
			args.Upsert = upsert;
			args.VersionReturned = returnNew ? FindAndModifyDocumentVersion.Modified : FindAndModifyDocumentVersion.Original;
			var r = _this.FindAndModify(args);
			result = new FindAndModifyUpdateResult(r);
			return r.GetModifiedDocumentAs(documentType);
		}
		public object FindAndRemoveAs(Type documentType, IMongoQuery query, IMongoSortBy sortBy)
		{
			var args = new FindAndRemoveArgs();
			args.Query = query;
			args.SortBy = sortBy;
			return _this.FindAndRemove(args).GetModifiedDocumentAs(documentType);
		}
		public WriteConcernResult Insert(BsonDocument document, WriteConcern writeConcern, bool needResult)
		{
			return _this.Insert(document, writeConcern);
		}
		public WriteConcernResult Save(BsonDocument document, WriteConcern writeConcern, bool needResult)
		{
			return _this.Save(document, writeConcern);
		}
		public WriteConcernResult Remove(IMongoQuery query, RemoveFlags flags, WriteConcern writeConcern, bool needResult)
		{
			return _this.Remove(query, flags, writeConcern);
		}
		public WriteConcernResult Update(IMongoQuery query, IMongoUpdate update, UpdateFlags flags, WriteConcern writeConcern, bool needResult)
		{
			return _this.Update(query, update, flags, writeConcern);
		}
	}
	abstract class UpdateResult
	{
		public abstract long DocumentsAffected { get; }
		public abstract bool UpdatedExisting { get; }
	}
	class SimpleUpdateResult : UpdateResult
	{
		readonly long _DocumentsAffected;
		readonly bool _UpdatedExisting;
		public SimpleUpdateResult(long documentsAffected, bool updatedExisting)
		{
			_DocumentsAffected = documentsAffected;
			_UpdatedExisting = updatedExisting;
		}
		public override long DocumentsAffected
		{
			get { return _DocumentsAffected; }
		}
		public override bool UpdatedExisting
		{
			get { return _UpdatedExisting; }
		}
	}
	class FindAndModifyUpdateResult : UpdateResult
	{
		readonly FindAndModifyResult Result;
		public FindAndModifyUpdateResult(FindAndModifyResult result)
		{
			Result = result;
		}
		public override long DocumentsAffected
		{
			get
			{
				BsonValue v;
				if (!Result.Response.TryGetValue("lastErrorObject", out v))
					return 0;
				if (!v.AsBsonDocument.TryGetValue("n", out v))
					return 0;
				return v.ToInt64();
			}
		}
		public override bool UpdatedExisting
		{
			get
			{
				BsonValue v;
				if (!Result.Response.TryGetValue("lastErrorObject", out v))
					return false;
				if (!v.AsBsonDocument.TryGetValue("updatedExisting", out v))
					return false;
				return v.ToBoolean();
			}
		}
	}
}
