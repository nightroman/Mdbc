
// Copyright (c) 2011-2016 Roman Kuzmin
// http://www.apache.org/licenses/LICENSE-2.0

using System;
using System.Management.Automation;
using MongoDB.Driver;

namespace Mdbc.Commands
{
	public abstract class AbstractWriteCommand : AbstractCollectionCommand
	{
		[Parameter]
		public WriteConcern WriteConcern { get; set; }

		[Parameter]
		public SwitchParameter Result { get; set; }

		protected void WriteResult(CommandResult result)
		{
			if (Result && result != null)
				WriteObject(result);
		}
	}
}
