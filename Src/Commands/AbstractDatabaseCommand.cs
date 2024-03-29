﻿
// Copyright (c) Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System.Management.Automation;
using MongoDB.Driver;

namespace Mdbc.Commands;

/// <summary>
/// Commands with the Database parameter.
/// </summary>
public abstract class AbstractDatabaseCommand : Abstract
{
	IMongoDatabase _Database;

	[Parameter]
	public IMongoDatabase Database
	{
		get => _Database ??= ResolveDatabase();
		set => _Database = value;
	}
}
