// This file is used by Code Analysis to maintain SuppressMessage 
// attributes that are applied to this project.
// Project-level suppressions either have no target or are given 
// a specific target and scoped to a namespace, type, member, etc.
//
// To add a suppression to this file, right-click the message in the 
// Error List, point to "Suppress Message(s)", and click 
// "In Project Suppression File".
// You do not need to add suppressions to this file manually.

[assembly: System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Design", "CA1020:AvoidNamespacesWithFewTypes", Scope = "namespace", Target = "Mdbc")]
[assembly: System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Design", "CA1031:DoNotCatchGeneralExceptionTypes", Scope = "member", Target = "Mdbc.Actor.#ToBsonDocument(System.Object,System.Collections.IEnumerable)")]
[assembly: System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Design", "CA1035:ICollectionImplementationsHaveStronglyTypedMembers", Scope = "type", Target = "Mdbc.Collection")]
[assembly: System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Design", "CA1035:ICollectionImplementationsHaveStronglyTypedMembers", Scope = "type", Target = "Mdbc.Dictionary")]
[assembly: System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Design", "CA1039:ListsAreStronglyTyped", Scope = "type", Target = "Mdbc.Collection")]
[assembly: System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Naming", "CA1721:PropertyNamesShouldNotMatchGetMethods", Scope = "member", Target = "Mdbc.Commands.NewQueryCommand.#Type")]
[assembly: System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Performance", "CA1819:PropertiesShouldNotReturnArrays", Scope = "member", Target = "Mdbc.Commands.GetDataCommand.#Select")]
[assembly: System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Performance", "CA1819:PropertiesShouldNotReturnArrays", Scope = "member", Target = "Mdbc.Commands.NewDataCommand.#Select")]
[assembly: System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Performance", "CA1819:PropertiesShouldNotReturnArrays", Scope = "member", Target = "Mdbc.Commands.NewQueryCommand.#Match")]
[assembly: System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Performance", "CA1819:PropertiesShouldNotReturnArrays", Scope = "member", Target = "Mdbc.Commands.NewQueryCommand.#Mod")]
[assembly: System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Performance", "CA1819:PropertiesShouldNotReturnArrays", Scope = "member", Target = "Mdbc.Commands.NewQueryCommand.#Queries")]
[assembly: System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Design", "CA2210:AssembliesShouldHaveValidStrongNames")]
