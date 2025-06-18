
using MongoDB.Bson;
using MongoDB.Driver;

namespace Mdbc.Commands;

static class CollectionExt
{
	public static long MyCount(this IMongoCollection<BsonDocument> collection, IClientSessionHandle session, FilterDefinition<BsonDocument> filter, long skip, long first)
	{
		if (skip <= 0 && first <= 0)
			return collection.CountDocuments(session, filter);

		var options = new CountOptions();
		if (skip > 0)
			options.Skip = skip;
		if (first > 0)
			options.Limit = first;

		return collection.CountDocuments(session, filter, options);
	}

	public static IEnumerable<BsonDocument> MyFind(this IMongoCollection<BsonDocument> collection, IClientSessionHandle session, FilterDefinition<BsonDocument> filter, SortDefinition<BsonDocument> sort, long skip, long first, ProjectionDefinition<BsonDocument> project)
	{
		var cursor = collection.Find(session, filter);
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

	public static BsonDocument MyFindOneAndDelete(this IMongoCollection<BsonDocument> collection, IClientSessionHandle session, FilterDefinition<BsonDocument> filter, SortDefinition<BsonDocument> sort, ProjectionDefinition<BsonDocument> project)
	{
		var args = new FindOneAndDeleteOptions<BsonDocument>();
		if (sort != null)
			args.Sort = sort;
		if (project != null)
			args.Projection = project;
		return collection.FindOneAndDelete(session, filter, args);
	}

	public static BsonDocument MyFindOneAndReplace(this IMongoCollection<BsonDocument> collection, IClientSessionHandle session, FilterDefinition<BsonDocument> filter, BsonDocument replace, SortDefinition<BsonDocument> sort, ProjectionDefinition<BsonDocument> project, bool returnNew, bool upsert)
	{
		var args = new FindOneAndReplaceOptions<BsonDocument, BsonDocument>();
		if (sort != null)
			args.Sort = sort;
		if (project != null)
			args.Projection = project;
		args.IsUpsert = upsert;
		args.ReturnDocument = returnNew ? ReturnDocument.After : ReturnDocument.Before;
		return collection.FindOneAndReplace(session, filter, replace, args);
	}

	public static BsonDocument MyFindOneAndUpdate(this IMongoCollection<BsonDocument> collection, IClientSessionHandle session, FilterDefinition<BsonDocument> filter, UpdateDefinition<BsonDocument> update, SortDefinition<BsonDocument> sort, ProjectionDefinition<BsonDocument> project, bool returnNew, bool upsert)
	{
		var args = new FindOneAndUpdateOptions<BsonDocument, BsonDocument>();
		if (sort != null)
			args.Sort = sort;
		if (project != null)
			args.Projection = project;
		args.IsUpsert = upsert;
		args.ReturnDocument = returnNew ? ReturnDocument.After : ReturnDocument.Before;
		return collection.FindOneAndUpdate(session, filter, update, args);
	}
}
