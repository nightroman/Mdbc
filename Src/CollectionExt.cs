
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using MongoDB.Bson;
using MongoDB.Driver;
using System.Collections.Generic;

namespace Mdbc
{
	static class CollectionExt
	{
		public static long MyCount(this IMongoCollection<BsonDocument> collection, FilterDefinition<BsonDocument> filter, long skip, long first)
		{
			if (skip <= 0 && first <= 0)
				return collection.CountDocuments(filter);

			var options = new CountOptions();
			if (skip > 0)
				options.Skip = skip;
			if (first > 0)
				options.Limit = first;

			return collection.CountDocuments(filter, options);
		}
		public static IEnumerable<BsonDocument> MyFind(this IMongoCollection<BsonDocument> collection, FilterDefinition<BsonDocument> filter, SortDefinition<BsonDocument> sort, long skip, long first, ProjectionDefinition<BsonDocument> project)
		{
			var cursor = collection.Find(filter);
			if (skip > 0)
				cursor = cursor.Skip((int)skip);
			if (first > 0)
				cursor = cursor.Limit((int)first);
			if (sort != null)
				cursor = cursor.Sort(sort);
			if (project != null)
				cursor = cursor.Project(project);

			return cursor.ToEnumerable();
		}
		public static BsonDocument MyFindOneAndDelete(this IMongoCollection<BsonDocument> collection, FilterDefinition<BsonDocument> filter, SortDefinition<BsonDocument> sort, ProjectionDefinition<BsonDocument> project)
		{
			var args = new FindOneAndDeleteOptions<BsonDocument>();
			if (sort != null)
				args.Sort = sort;
			if (project != null)
				args.Projection = project;
			return collection.FindOneAndDelete(filter, args);
		}
		public static BsonDocument MyFindOneAndReplace(this IMongoCollection<BsonDocument> collection, FilterDefinition<BsonDocument> filter, BsonDocument replace, SortDefinition<BsonDocument> sort, ProjectionDefinition<BsonDocument> project, bool returnNew, bool upsert)
		{
			var args = new FindOneAndReplaceOptions<BsonDocument, BsonDocument>();
			if (sort != null)
				args.Sort = sort;
			if (project != null)
				args.Projection = project;
			args.IsUpsert = upsert;
			args.ReturnDocument = returnNew ? ReturnDocument.After : ReturnDocument.Before;
			return collection.FindOneAndReplace(filter, replace, args);
		}
		public static BsonDocument MyFindOneAndUpdate(this IMongoCollection<BsonDocument> collection, FilterDefinition<BsonDocument> filter, UpdateDefinition<BsonDocument> update, SortDefinition<BsonDocument> sort, ProjectionDefinition<BsonDocument> project, bool returnNew, bool upsert)
		{
			var args = new FindOneAndUpdateOptions<BsonDocument, BsonDocument>();
			if (sort != null)
				args.Sort = sort;
			if (project != null)
				args.Projection = project;
			args.IsUpsert = upsert;
			args.ReturnDocument = returnNew ? ReturnDocument.After : ReturnDocument.Before;
			return collection.FindOneAndUpdate(filter, update, args);
		}
	}
}
