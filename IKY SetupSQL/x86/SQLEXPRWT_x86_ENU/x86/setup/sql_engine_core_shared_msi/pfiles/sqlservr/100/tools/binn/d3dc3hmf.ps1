<?xml version="1.0" encoding="utf-8" ?>
<!-- *******************************************************************
Copyright (c) Microsoft Corporation.  All rights reserved.
******************************************************************** -->

<Configuration>


  <SelectionSets>
    <SelectionSet>
      <Name>RegisteredServerTypes</Name>
      <Types>
        <TypeName>Microsoft.SqlServer.Management.RegisteredServers.ServerGroup</TypeName>
        <TypeName>Microsoft.SqlServer.Management.RegisteredServers.RegisteredServer</TypeName>
      </Types>
    </SelectionSet>
  </SelectionSets>

  <!-- ################ GLOBAL CONTROL DEFINITIONS ################ -->
  <Controls>
    <Control>
      <Name>RegisteredServerTypes-GroupingFormat</Name>
      <CustomControl>
        <CustomEntries>
          <CustomEntry>
            <CustomItem>
              <Frame>
                <LeftIndent>4</LeftIndent>
                <CustomItem>
                  <Text>Directory: </Text>
                  <ExpressionBinding>
                    <ScriptBlock>$_.PSParentPath</ScriptBlock>
                  </ExpressionBinding>
                  <NewLine/>
                </CustomItem>
              </Frame>
            </CustomItem>
          </CustomEntry>
        </CustomEntries>
      </CustomControl>
    </Control>
  </Controls>



  <ViewDefinitions>

    <!-- SMO -->

    <View>
      <Name>Server</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.Smo.Server</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>

          <TableColumnHeader>
            <Label>Instance Name</Label>
            <Width>80</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <TableColumnItems>

              <TableColumnItem>
                <PropertyName>DisplayName</PropertyName>
              </TableColumnItem>

            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>

    <View>
      <Name>Database</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.Smo.Database</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>

          <TableColumnHeader>
            <Label>Name</Label>
            <Width>20</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Status</Label>
            <Width>15</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Recovery Model</Label>
            <Width>14</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>CompatLvl</Label>
            <Width>9</Width>
            <Alignment>right</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Collation</Label>
            <Width>30</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Owner</Label>
            <Width>25</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <Wrap/>
            <TableColumnItems>

              <TableColumnItem>
                <PropertyName>Name</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>Status</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>RecoveryModel</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <ScriptBlock>
                  [int] $_.CompatibilityLevel
                </ScriptBlock>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>Collation</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>Owner</PropertyName>
              </TableColumnItem>

            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>

    <View>
      <Name>Table</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.Smo.Table</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>

          <TableColumnHeader>
            <Label>Schema</Label>
            <Width>28</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Name</Label>
            <Width>30</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Created</Label>
            <Width>22</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <Wrap/>
            <TableColumnItems>

              <TableColumnItem>
                <PropertyName>Schema</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>Name</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <ScriptBlock>$_.CreateDate.ToString("g")</ScriptBlock>
              </TableColumnItem>

            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>

    <View>
      <Name>View</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.Smo.View</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>

          <TableColumnHeader>
            <Label>Schema</Label>
            <Width>28</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Name</Label>
            <Width>30</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Created</Label>
            <Width>22</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <Wrap/>
            <TableColumnItems>

              <TableColumnItem>
                <PropertyName>Schema</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>Name</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <ScriptBlock>$_.CreateDate.ToString("g")</ScriptBlock>
              </TableColumnItem>

            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>

    <View>
      <Name>StoredProcedure</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.Smo.StoredProcedure</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>

          <TableColumnHeader>
            <Label>Schema</Label>
            <Width>28</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Name</Label>
            <Width>30</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Created</Label>
            <Width>22</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <Wrap/>
            <TableColumnItems>

              <TableColumnItem>
                <PropertyName>Schema</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>Name</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <ScriptBlock>$_.CreateDate.ToString("g")</ScriptBlock>
              </TableColumnItem>

            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>

    <View>
      <Name>User</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.Smo.User</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>

          <TableColumnHeader>
            <Label>Name</Label>
            <Width>30</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Login</Label>
            <Width>28</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Created</Label>
            <Width>22</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <Wrap/>
            <TableColumnItems>

              <TableColumnItem>
                <PropertyName>Name</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>Login</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <ScriptBlock>$_.CreateDate.ToString("g")</ScriptBlock>
              </TableColumnItem>

            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>

    <View>
      <Name>Login</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.Smo.Login</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>

          <TableColumnHeader>
            <Label>Name</Label>
            <Width>45</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Login Type</Label>
            <Width>13</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Created</Label>
            <Width>22</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <Wrap/>
            <TableColumnItems>

              <TableColumnItem>
                <PropertyName>Name</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>LoginType</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <ScriptBlock>$_.CreateDate.ToString("g")</ScriptBlock>
              </TableColumnItem>

            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>

    <View>
      <Name>Schema</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.Smo.Schema</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>

          <TableColumnHeader>
            <Label>Name</Label>
            <Width>30</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Owner</Label>
            <Width>28</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <Wrap/>
            <TableColumnItems>

              <TableColumnItem>
                <PropertyName>Name</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>Owner</PropertyName>
              </TableColumnItem>

            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>

    <View>
      <Name>Index</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.Smo.Index</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>

          <TableColumnHeader>
            <Label>Name</Label>
            <Width>80</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <Wrap/>
            <TableColumnItems>

              <TableColumnItem>
                <PropertyName>Name</PropertyName>
              </TableColumnItem>

            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>

    <View>
      <Name>Trigger</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.Smo.Trigger</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>

          <TableColumnHeader>
            <Label>Name</Label>
            <Width>30</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Created</Label>
            <Width>22</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <Wrap/>
            <TableColumnItems>

              <TableColumnItem>
                <PropertyName>Name</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <ScriptBlock>$_.CreateDate.ToString("g")</ScriptBlock>
              </TableColumnItem>

            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>

    <View>
      <Name>UserDefinedFunction</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.Smo.UserDefinedFunction</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>

          <TableColumnHeader>
            <Label>Schema</Label>
            <Width>28</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Name</Label>
            <Width>30</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Created</Label>
            <Width>22</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <Wrap/>
            <TableColumnItems>

              <TableColumnItem>
                <PropertyName>Schema</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>Name</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <ScriptBlock>$_.CreateDate.ToString("g")</ScriptBlock>
              </TableColumnItem>

            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>


    <View>
      <Name>SystemMessage</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.Smo.SystemMessage</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>

          <TableColumnHeader>
            <Label>ID</Label>
            <Width>5</Width>
            <Alignment>right</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Language</Label>
            <Width>15</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Text</Label>
            <Width>58</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <Wrap/>
            <TableColumnItems>

              <TableColumnItem>
                <PropertyName>ID</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>Language</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>Text</PropertyName>
              </TableColumnItem>

            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>

    <View>
      <Name>UserDefinedMessage</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.Smo.UserDefinedMessage</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>

          <TableColumnHeader>
            <Label>ID</Label>
            <Width>5</Width>
            <Alignment>right</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Language</Label>
            <Width>15</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Text</Label>
            <Width>58</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <Wrap/>
            <TableColumnItems>

              <TableColumnItem>
                <PropertyName>ID</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>Language</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>Text</PropertyName>
              </TableColumnItem>

            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>


    <!-- DMF -->

    <View>
      <Name>PolicyStore</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.Dmf.PolicyStore</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>

          <TableColumnHeader>
            <Label>Instance Name</Label>
            <Width>80</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <TableColumnItems>

              <TableColumnItem>
                <PropertyName>DisplayName</PropertyName>
              </TableColumnItem>

            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>

    <View>
      <Name>Policy</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.Dmf.Policy</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>

          <TableColumnHeader>
            <Label>Name</Label>
            <Width>30</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Category</Label>
            <Width>17</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Created</Label>
            <Width>22</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Enabled</Label>
            <Width>7</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <TableColumnItems>

              <TableColumnItem>
                <PropertyName>Name</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>PolicyCategory</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <ScriptBlock>$_.CreateDate.ToString("g")</ScriptBlock>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>Enabled</PropertyName>
              </TableColumnItem>

            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>

    <View>
      <Name>EvaluationHistory</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.Dmf.EvaluationHistory</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>

          <TableColumnHeader>
            <Label>ID</Label>
            <Width>5</Width>
            <Alignment>right</Alignment>
          </TableColumnHeader>
          
          <TableColumnHeader>
            <Label>Policy Name</Label>
            <Width>30</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Result</Label>
            <Width>6</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Start Date</Label>
            <Width>18</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>End Date</Label>
            <Width>18</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Messages</Label>
            <Width>22</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <Wrap/>
            <TableColumnItems>

              <TableColumnItem>
                <PropertyName>ID</PropertyName>
              </TableColumnItem>
              
              <TableColumnItem>
                <PropertyName>PolicyName</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>Result</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <ScriptBlock>$_.StartDate.ToString("g")</ScriptBlock>
              </TableColumnItem>

              <TableColumnItem>
                <ScriptBlock>$_.EndDate.ToString("g")</ScriptBlock>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>Exception</PropertyName>
              </TableColumnItem>

            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>

    <View>
      <Name>ConnectionEvaluationHistory</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.Dmf.ConnectionEvaluationHistory</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>

          <TableColumnHeader>
            <Label>ID</Label>
            <Width>5</Width>
            <Alignment>right</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Server Instance</Label>
            <Width>30</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Result</Label>
            <Width>6</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Messages</Label>
            <Width>22</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <Wrap/>
            <TableColumnItems>

              <TableColumnItem>
                <PropertyName>ID</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>ServerInstance</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>Result</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>Exception</PropertyName>
              </TableColumnItem>

            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>

    
    <View>
      <Name>EvaluationDetail</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.Dmf.EvaluationDetail</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>

          <TableColumnHeader>
            <Label>ID</Label>
            <Width>5</Width>
            <Alignment>right</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Result</Label>
            <Width>6</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Target Query Expression</Label>
            <Width>40</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Messages</Label>
            <Width>22</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <Wrap/>
            <TableColumnItems>

              <TableColumnItem>
                <PropertyName>ID</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>Result</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>TargetQueryExpression</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <ScriptBlock>Exception</ScriptBlock>
              </TableColumnItem>

            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>

    <View>
      <Name>TargetSet</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.Dmf.TargetSet</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>

          <TableColumnHeader>
            <Label>ID</Label>
            <Width>5</Width>
            <Alignment>right</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Target Type</Label>
            <Width>20</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Target Type Skeleton</Label>
            <Width>40</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Enabled</Label>
            <Width>5</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <TableColumnItems>

              <TableColumnItem>
                <PropertyName>ID</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>TargetType</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>TargetTypeSkeleton</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>Enabled</PropertyName>
              </TableColumnItem>

            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>

    
    <View>
      <Name>TargetSetLevel</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.Dmf.TargetSetLevel</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>

          <TableColumnHeader>
            <Label>ID</Label>
            <Width>5</Width>
            <Alignment>right</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Condition</Label>
            <Width>20</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Target Type Skeleton</Label>
            <Width>40</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Level Name</Label>
            <Width>20</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <TableColumnItems>

              <TableColumnItem>
                <PropertyName>ID</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>Condition</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>TargetTypeSkeleton</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>LevelName</PropertyName>
              </TableColumnItem>

            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>


    <View>
      <Name>Condition</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.Dmf.Condition</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>

          <TableColumnHeader>
            <Label>Name</Label>
            <Width>30</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Facet</Label>
            <Width>25</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Created</Label>
            <Width>22</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <TableColumnItems>

              <TableColumnItem>
                <PropertyName>Name</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>Facet</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <ScriptBlock>$_.CreateDate.ToString("g")</ScriptBlock>
              </TableColumnItem>

            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>


    <View>
      <Name>PolicyCategory</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.Dmf.PolicyCategory</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>

          <TableColumnHeader>
            <Label>ID</Label>
            <Width>5</Width>
            <Alignment>right</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Name</Label>
            <Width>30</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Mandate Database Subscriptions</Label>
            <Width>30</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <TableColumnItems>

              <TableColumnItem>
                <PropertyName>ID</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>Name</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>MandateDatabaseSubscriptions</PropertyName>
              </TableColumnItem>

            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>

    <View>
      <Name>PolicyCategorySubscription</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.Dmf.PolicyCategorySubscription</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>

          <TableColumnHeader>
            <Label>ID</Label>
            <Width>5</Width>
            <Alignment>right</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Policy Category</Label>
            <Width>23</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Target</Label>
            <Width>23</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Target Type</Label>
            <Width>23</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>


        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <TableColumnItems>

              <TableColumnItem>
                <PropertyName>ID</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>PolicyCategory</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>Target</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>TargetType</PropertyName>
              </TableColumnItem>

            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>


    <View>
      <Name>ObjectSet</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.Dmf.ObjectSet</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>

          <TableColumnHeader>
            <Label>Name</Label>
            <Width>30</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Facet</Label>
            <Width>25</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>


        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <TableColumnItems>

              <TableColumnItem>
                <PropertyName>Name</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>Facet</PropertyName>
              </TableColumnItem>

            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>

    <!-- SQL Server Registrations -->

    <View>
      <Name>children</Name>
      <ViewSelectedBy>
        <SelectionSetName>RegisteredServerTypes</SelectionSetName>
      </ViewSelectedBy>
      <GroupBy>
        <PropertyName>PSParentPath</PropertyName>
        <CustomControlName>RegisteredServerTypes-GroupingFormat</CustomControlName>
      </GroupBy>
      <TableControl>
        <TableHeaders>
          <TableColumnHeader>
            <Label>Mode</Label>
            <Width>4</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>
          <TableColumnHeader>
            <Label>Name</Label>
            <Width>40</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>
        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <Wrap/>
            <TableColumnItems>
              <TableColumnItem>
                <PropertyName>Mode</PropertyName>
              </TableColumnItem>
              <TableColumnItem>
                <PropertyName>DisplayName</PropertyName>
              </TableColumnItem>
            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>
    <View>
      <Name>children</Name>
      <ViewSelectedBy>
        <SelectionSetName>RegisteredServerTypes</SelectionSetName>
      </ViewSelectedBy>
      <GroupBy>
        <PropertyName>PSParentPath</PropertyName>
        <CustomControlName>RegisteredServerTypes-GroupingFormat</CustomControlName>
      </GroupBy>
      <ListControl>
        <ListEntries>
          <ListEntry>
            <EntrySelectedBy>
              <TypeName>Microsoft.SqlServer.Management.RegisteredServers.ServerGroup</TypeName>
            </EntrySelectedBy>
            <ListItems>
              <ListItem>
                <PropertyName>DisplayName</PropertyName>
              </ListItem>
            </ListItems>
          </ListEntry>
          <ListEntry>
            <ListItems>
              <ListItem>
                <PropertyName>DisplayName</PropertyName>
              </ListItem>
            </ListItems>
          </ListEntry>
        </ListEntries>
      </ListControl>
    </View>

    <!-- Data Collector -->


   <View>
      <Name>CollectionSet</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.Collector.CollectionSet</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>

          <TableColumnHeader>
            <Label>Name</Label>
            <Width>30</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>IsRunning</Label>
            <Width>10</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Description</Label>
            <Width>36</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <Wrap/>
            <TableColumnItems>

              <TableColumnItem>
                <PropertyName>Name</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>IsRunning</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>Description</PropertyName>
              </TableColumnItem>

            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>

   <View>
      <Name>CollectionItem</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.Collector.CollectionItem</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>

          <TableColumnHeader>
            <Label>Name</Label>
            <Width>30</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Collector Type</Label>
            <Width>27</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Collection Frequency</Label>
            <Width>21</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>


        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <TableColumnItems>

              <TableColumnItem>
                <PropertyName>Name</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>TypeName</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>CollectionFrequency</PropertyName>
              </TableColumnItem>

            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>


    <!-- SQL Server Provider Types -->

    <View>
      <Name>SqlServerProviderExtension</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.PowerShell.Extensions.SqlServerProviderExtension</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>
          <TableColumnHeader>
            <Label>Name</Label>
            <Width>15</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>
          <TableColumnHeader>
            <Label>Root</Label>
            <Width>30</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>
          <TableColumnHeader>
            <Label>Description</Label>
            <Width>40</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>
        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <Wrap/>
            <TableColumnItems>
              <TableColumnItem>
                <PropertyName>Name</PropertyName>
              </TableColumnItem>
              <TableColumnItem>
                <PropertyName>Root</PropertyName>
              </TableColumnItem>
              <TableColumnItem>
                <PropertyName>Description</PropertyName>
              </TableColumnItem>
            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>

    <View>
      <Name>Machine</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.PowerShell.Extensions.Machine</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>
          <TableColumnHeader>
            <Label>MachineName</Label>
            <Width>32</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>
        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <Wrap/>
            <TableColumnItems>
              <TableColumnItem>
                <PropertyName>MachineName</PropertyName>
              </TableColumnItem>
            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>


    <View>
      <Name>CollectionInfo</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.Sdk.Sfc.CollectionInfo</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>
          <TableColumnHeader>
            <Label>Name</Label>
            <Width>60</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>
        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <Wrap/>
            <TableColumnItems>
              <TableColumnItem>
                <PropertyName>DisplayName</PropertyName>
              </TableColumnItem>
            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>


   <!-- Utility -->

    <View>
      <Name>Utility</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.Utility.Utility</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>

          <TableColumnHeader>
            <Label>Instance Name</Label>
            <Width>80</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <TableColumnItems>

              <TableColumnItem>
                <PropertyName>DisplayName</PropertyName>
              </TableColumnItem>

            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>

   <View>
      <Name>Computer</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.Utility.Computer</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>

          <TableColumnHeader>
            <Label>Name</Label>
            <Width>30</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Clustered</Label>
            <Width>27</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <TableColumnItems>

              <TableColumnItem>
                <PropertyName>Name</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>IsClustered</PropertyName>
              </TableColumnItem>

            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>

    <View>
      <Name>Volume</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.Utility.Volume</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>

          <TableColumnHeader>
            <Label>Mount Point</Label>
            <Width>12</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>
          
          <TableColumnHeader>
            <Label>Space Utilization %</Label>
            <Width>20</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Total Space</Label>
            <Width>20</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Total Space Used</Label>
            <Width>20</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>
          
        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <TableColumnItems>

              <TableColumnItem>
                <PropertyName>MountPointLocation</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>TotalSpaceUtilization</PropertyName>
              </TableColumnItem>
              
              <TableColumnItem>
                <PropertyName>TotalSpace</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>TotalSpaceUsed</PropertyName>
              </TableColumnItem>
              
            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>

    <View>
      <Name>Processor</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.Utility.Processor</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>

          <TableColumnHeader>
            <Label>Processor Name</Label>
            <Width>16</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Architecture</Label>
            <Width>18</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Clock Speed</Label>
            <Width>20</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <TableColumnItems>

              <TableColumnItem>
                <PropertyName>Name</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>Architecture</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>ClockSpeed</PropertyName>
              </TableColumnItem>

            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>
    
    <View>
      <Name>ImportedObject</Name>
      <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.Utility.ImportedObject</TypeName>
      </ViewSelectedBy>
      <TableControl>
        <TableHeaders>

          <TableColumnHeader>
            <Label>Name</Label>
            <Width>30</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

          <TableColumnHeader>
            <Label>Version</Label>
            <Width>27</Width>
            <Alignment>left</Alignment>
          </TableColumnHeader>

        </TableHeaders>
        <TableRowEntries>
          <TableRowEntry>
            <TableColumnItems>

              <TableColumnItem>
                <PropertyName>Name</PropertyName>
              </TableColumnItem>

              <TableColumnItem>
                <PropertyName>Version</PropertyName>
              </TableColumnItem>

            </TableColumnItems>
          </TableRowEntry>
        </TableRowEntries>
      </TableControl>
    </View>

  <!-- DAC -->

  <View>
      <Name>DAC</Name>
      <ViewSelectedBy>
          <TypeName>Microsoft.SqlServer.Management.DAC.DacStore</TypeName>
      </ViewSelectedBy>
      <TableControl>
          <TableHeaders>

              <TableColumnHeader>
                  <Label>Name</Label>
                  <Width>80</Width>
                  <Alignment>left</Alignment>
              </TableColumnHeader>

          </TableHeaders>
          <TableRowEntries>
              <TableRowEntry>
                  <TableColumnItems>

                      <TableColumnItem>
                          <PropertyName>Name</PropertyName>
                      </TableColumnItem>

                  </TableColumnItems>
              </TableRowEntry>
          </TableRowEntries>
      </TableControl>
  </View>
  <View>
    <Name>DacPackage</Name>
    <ViewSelectedBy>
        <TypeName>Microsoft.SqlServer.Management.DAC.DacInstance</TypeName>
    </ViewSelectedBy>
    <TableControl>
        <TableHeaders>

            <TableColumnHeader>
                <Label>Instance Name</Label>
                <Width>30</Width>
                <Alignment>left</Alignment>
            </TableColumnHeader>

            <TableColumnHeader>
                <Label>Application Name</Label>
                <Width>30</Width>
                <Alignment>left</Alignment>
            </TableColumnHeader>

            <TableColumnHeader>
                <Label>Application Version</Label>
                <Width>27</Width>
                <Alignment>left</Alignment>
            </TableColumnHeader>

        </TableHeaders>
        <TableRowEntries>
            <TableRowEntry>
                <TableColumnItems>

                    <TableColumnItem>
                        <PropertyName>Name</PropertyName>
                    </TableColumnItem>

                    <TableColumnItem>
                        <ScriptBlock>$_.Type.Name</ScriptBlock>
                    </TableColumnItem>

                    <TableColumnItem>
                        <ScriptBlock>$_.Type.Version</ScriptBlock>
                    </TableColumnItem>

                </TableColumnItems>
            </TableRowEntry>
        </TableRowEntries>
    </TableControl>
  </View>
  </ViewDefinitions>
</Configuration>

<!-- SIG # Begin signature block -->
<!-- MIIbNQYJKoZIhvcNAQcCoIIbJjCCGyICAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB -->
<!-- gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR -->
<!-- AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUXxVE2YQsb7waqw/MxL6UnLtB -->
<!-- WAKgghXnMIIEhTCCA22gAwIBAgIKYQRMSwAAAAAAJDANBgkqhkiG9w0BAQUFADB5 -->
<!-- MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk -->
<!-- bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSMwIQYDVQQDExpN -->
<!-- aWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQTAeFw0wODEwMjIyMjQxMzhaFw0xMDAx -->
<!-- MjIyMjUxMzhaMIGDMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQ -->
<!-- MA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9u -->
<!-- MQ0wCwYDVQQLEwRNT1BSMR4wHAYDVQQDExVNaWNyb3NvZnQgQ29ycG9yYXRpb24w -->
<!-- ggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDld0DnyOpP8stYilPmVuX3 -->
<!-- G6/GYw10W26iyfPVO4HeXRErVS0DGlAzhlEaE25Mu8Lra2YTjJQp07nrdUj3uasP -->
<!-- YE2bzVVwNYAmbKkfy7QkgJAFh3cVLTcPTfY0Sro6wCQVkIOybd8d5IcBF4166fEy -->
<!-- P/Imh2uEc3J+/M/Gu3X3InFDvSy11/AILyqZflv0CDofLb6Enl3wH/BDzX4zWJ1L -->
<!-- jFA8QCyKZw4lEadvuPM/Kg4daXdfaAj7v5iOkk8fJIGHriBaLj6SdYDL6KAFAQqN -->
<!-- qMEmlFjAJce20NaDVWCUrP3XWFk9OS2fCAOK4UUXluThk58dCx1QfjjjrNDLl8x7 -->
<!-- AgMBAAGjggECMIH/MBMGA1UdJQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBQj0ult -->
<!-- uWMPZkEI7aFkwrCUaIDvSDAOBgNVHQ8BAf8EBAMCB4AwHwYDVR0jBBgwFoAUV0V0 -->
<!-- HF2w9shDBeCMVC2PMqf+SJYwSQYDVR0fBEIwQDA+oDygOoY4aHR0cDovL2NybC5t -->
<!-- aWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvQ29kZVNpZ1BDQS5jcmwwTQYI -->
<!-- KwYBBQUHAQEEQTA/MD0GCCsGAQUFBzAChjFodHRwOi8vd3d3Lm1pY3Jvc29mdC5j -->
<!-- b20vcGtpL2NlcnRzL0NvZGVTaWdQQ0EuY3J0MA0GCSqGSIb3DQEBBQUAA4IBAQBT -->
<!-- 8WrdYH3fq+E17nr0zvzlfi1mOvrfNi+uqT3L1hVB38bQA2WW+2QObUqKM2312AhS -->
<!-- eNIXXOz2w7gUbh2E/2nUxPYJpLamphgGi/xMUdw3CNfzfoOqvZA5euagGulQmb5i -->
<!-- R2/JNqLpP5HLjvv3nTtlDDDLOqY/tdkTFrv2Yvhv9doT/5sG9v3HOUE3IlCKTEFh -->
<!-- t6H2iDntAKAQtDJ+yZED2S+aR/uONxdBYTTg8bo0h2S3cUyW8Duuz8X2kB0GElS7 -->
<!-- by7iiklcPONc86QZWQammI+/IKSTbLN/BEgC9i1YD/y01UIDrVhr+W9kVpVzGgEr -->
<!-- Bca9L/i8/ivAmcmo7IB7MIIEyjCCA7KgAwIBAgIKYQSz9QAAAAAADTANBgkqhkiG -->
<!-- 9w0BAQUFADB3MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G -->
<!-- A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEw -->
<!-- HwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EwHhcNMDgwNzI1MTkxMzQ1 -->
<!-- WhcNMTEwNzI1MTkyMzQ1WjCBszELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp -->
<!-- bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw -->
<!-- b3JhdGlvbjENMAsGA1UECxMETU9QUjEnMCUGA1UECxMebkNpcGhlciBEU0UgRVNO -->
<!-- OjlFNzgtODY0Qi0wMzlEMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBT -->
<!-- ZXJ2aWNlMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAq0YvvKgU8vhG -->
<!-- PwwFoaRjRQV/mukzcswn0zLsmMPgNIiFzqESl65IUE5IIH9w5Fkz/JlbuQeASCi8 -->
<!-- jbj6ZgJmtfF/HFCWKJNVjYFVqnBbpcnO7y7i5yXDdm8pC58syFOAmsEN472nRb8x -->
<!-- 3+aGi32JAYsceFg4st2TSlueHdecxvDETdC/J0oHlARxAogNcOb4KucOYeOYS9Hd -->
<!-- q1S2N/vGRv2kHLz/r+yyl4DcuJP9uCKonSVZcD5cexxBKf5zmSJJgddVJsDs8k4o -->
<!-- VGI7cC1hkx1Q1Z8BwgXDVRpKh6QAhlSge2Ky6g/6XVzFKhGCl76GGx2rt6sKKfzM -->
<!-- zTSJv0C2TwIDAQABo4IBGTCCARUwHQYDVR0OBBYEFKCFMV6Hrg+qCgTr4cDTZL08 -->
<!-- u2n1MB8GA1UdIwQYMBaAFCM0+NlSRnAK7UD7dvuzK7DDNbMPMFQGA1UdHwRNMEsw -->
<!-- SaBHoEWGQ2h0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3Rz -->
<!-- L01pY3Jvc29mdFRpbWVTdGFtcFBDQS5jcmwwWAYIKwYBBQUHAQEETDBKMEgGCCsG -->
<!-- AQUFBzAChjxodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY3Jv -->
<!-- c29mdFRpbWVTdGFtcFBDQS5jcnQwEwYDVR0lBAwwCgYIKwYBBQUHAwgwDgYDVR0P -->
<!-- AQH/BAQDAgbAMA0GCSqGSIb3DQEBBQUAA4IBAQBHcU+2SEXACOucL9MlW9tnURGS -->
<!-- ptnZshSaJsL9BsHM14j1pjW1zSu2a1hqzfmd81rrRi+h+qcffXpCsrDRGgkoVGxv -->
<!-- mYs4/DrkwSSqckwSBC/x1Hp2O8XPcScLbfw4Z6fFImIre3/BdqynxSZMqa+Y3Yo4 -->
<!-- Xc9lpIEuqe9WAky5CL5lxB6LIS1up/J1ZLTcGmvQ8SXlwueARDnULwp5fgEqp3hb -->
<!-- o2tbzgnvOTo5t8RnU7mq82H/nXnjz0hn/6vIxitiCZTQH6J493NJO1hTwQmrTAYL -->
<!-- 1UAofvaxZsW/UsS+Pjvg+Y50jeYiDMHGM5i1eegM9wB86rJOzICaFi3IpBAFMIIG -->
<!-- BzCCA++gAwIBAgIKYRZoNAAAAAAAHDANBgkqhkiG9w0BAQUFADBfMRMwEQYKCZIm -->
<!-- iZPyLGQBGRYDY29tMRkwFwYKCZImiZPyLGQBGRYJbWljcm9zb2Z0MS0wKwYDVQQD -->
<!-- EyRNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkwHhcNMDcwNDAz -->
<!-- MTI1MzA5WhcNMjEwNDAzMTMwMzA5WjB3MQswCQYDVQQGEwJVUzETMBEGA1UECBMK -->
<!-- V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0 -->
<!-- IENvcnBvcmF0aW9uMSEwHwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0Ew -->
<!-- ggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCfoWyx39tIkip8ay4Z4b3i -->
<!-- 48WZUSNQrc7dGE4kD+7Rp9FMrXQwIBHrB9VUlRVJlBtCkq6YXDAm2gBr6Hu97IkH -->
<!-- D/cOBJjwicwfyzMkh53y9GccLPx754gd6udOo6HBI1PKjfpFzwnQXq/QsEIEovmm -->
<!-- bJNn1yjcRlOwhtDlKEYuJ6yGT1VSDOQDLPtqkJAwbofzWTCd+n7Wl7PoIZd++NIT -->
<!-- 8wi3U21StEWQn0gASkdmEScpZqiX5NMGgUqi+YSnEUcUCYKfhO1VeP4Bmh1QCIUA -->
<!-- EDBG7bfeI0a7xC1Un68eeEExd8yb3zuDk6FhArUdDbH895uyAc4iS1T/+QXDwiAL -->
<!-- AgMBAAGjggGrMIIBpzAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBQjNPjZUkZw -->
<!-- Cu1A+3b7syuwwzWzDzALBgNVHQ8EBAMCAYYwEAYJKwYBBAGCNxUBBAMCAQAwgZgG -->
<!-- A1UdIwSBkDCBjYAUDqyCYEBWJ5flJRP8KuEKU5VZ5KShY6RhMF8xEzARBgoJkiaJ -->
<!-- k/IsZAEZFgNjb20xGTAXBgoJkiaJk/IsZAEZFgltaWNyb3NvZnQxLTArBgNVBAMT -->
<!-- JE1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eYIQea0WoUqgpa1M -->
<!-- c1j0BxMuZTBQBgNVHR8ESTBHMEWgQ6BBhj9odHRwOi8vY3JsLm1pY3Jvc29mdC5j -->
<!-- b20vcGtpL2NybC9wcm9kdWN0cy9taWNyb3NvZnRyb290Y2VydC5jcmwwVAYIKwYB -->
<!-- BQUHAQEESDBGMEQGCCsGAQUFBzAChjhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20v -->
<!-- cGtpL2NlcnRzL01pY3Jvc29mdFJvb3RDZXJ0LmNydDATBgNVHSUEDDAKBggrBgEF -->
<!-- BQcDCDANBgkqhkiG9w0BAQUFAAOCAgEAEJeKw1wDRDbd6bStd9vOeVFNAbEudHFb -->
<!-- bQwTq86+e4+4LtQSooxtYrhXAstOIBNQmd16QOJXu69YmhzhHQGGrLt48ovQ7DsB -->
<!-- 7uK+jwoFyI1I4vBTFd1Pq5Lk541q1YDB5pTyBi+FA+mRKiQicPv2/OR4mS4N9wfi -->
<!-- cLwYTp2OawpylbihOZxnLcVRDupiXD8WmIsgP+IHGjL5zDFKdjE9K3ILyOpwPf+F -->
<!-- ChPfwgphjvDXuBfrTot/xTUrXqO/67x9C0J71FNyIe4wyrt4ZVxbARcKFA7S2hSY -->
<!-- 9Ty5ZlizLS/n+YWGzFFW6J1wlGysOUzU9nm/qhh6YinvopspNAZ3GmLJPR5tH4Lw -->
<!-- C8csu89Ds+X57H2146SodDW4TsVxIxImdgs8UoxxWkZDFLyzs7BNZ8ifQv+AeSGA -->
<!-- nhUwZuhCEl4ayJ4iIdBD6Svpu/RIzCzU2DKATCYqSCRfWupW76bemZ3KOm+9gSd0 -->
<!-- BhHudiG/m4LBJ1S2sWo9iaF2YbRuoROmv6pH8BJv/YoybLL+31HIjCPJZr2dHYcS -->
<!-- ZAI9La9Zj7jkIeW1sMpjtHhUBdRBLlCslLCleKuzoJZ1GtmShxN1Ii8yqAhuoFuM -->
<!-- Jb+g74TKIdbrHk/Jmu5J4PcBZW+JC33Iacjmbuqnl84xKf8OxVtc2E0bodj6L54/ -->
<!-- LlUWa8kTo/0wggaBMIIEaaADAgECAgphFQgnAAAAAAAMMA0GCSqGSIb3DQEBBQUA -->
<!-- MF8xEzARBgoJkiaJk/IsZAEZFgNjb20xGTAXBgoJkiaJk/IsZAEZFgltaWNyb3Nv -->
<!-- ZnQxLTArBgNVBAMTJE1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0 -->
<!-- eTAeFw0wNjAxMjUyMzIyMzJaFw0xNzAxMjUyMzMyMzJaMHkxCzAJBgNVBAYTAlVT -->
<!-- MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK -->
<!-- ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xIzAhBgNVBAMTGk1pY3Jvc29mdCBDb2Rl -->
<!-- IFNpZ25pbmcgUENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAn43f -->
<!-- hTeMsQZWZjZO1ArrNiORHq+rjVjpxM/BnzoKJMTExF6w7hUUxfo+mTNrGWly9HwF -->
<!-- X+WZJUTXNRmKkNwojpAM79WQYa3e3BhwLYPJb6+FLPjdubkw/XF4HIP9yKm5gmcN -->
<!-- erjBCcK8FpdXPxyY02nXMJCQkI0wH9gm1J57iNniCe2XSUXrBFKBdXu4tSK4Lla7 -->
<!-- 18+pTjwKg6KoOsWttgEOas8itCMfbNUn57d+wbTVMq15JRxChuKdhfRX2htZLy0m -->
<!-- kinFs9eFo55gWpTme5x7XoI0S23/1O4n0KLc0ZAMzn0OFXyIrDTHwGyYhErJRHlo -->
<!-- KN8igw24iixIYeL+EQIDAQABo4ICIzCCAh8wEAYJKwYBBAGCNxUBBAMCAQAwHQYD -->
<!-- VR0OBBYEFFdFdBxdsPbIQwXgjFQtjzKn/kiWMAsGA1UdDwQEAwIBxjAPBgNVHRMB -->
<!-- Af8EBTADAQH/MIGYBgNVHSMEgZAwgY2AFA6sgmBAVieX5SUT/CrhClOVWeSkoWOk -->
<!-- YTBfMRMwEQYKCZImiZPyLGQBGRYDY29tMRkwFwYKCZImiZPyLGQBGRYJbWljcm9z -->
<!-- b2Z0MS0wKwYDVQQDEyRNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3Jp -->
<!-- dHmCEHmtFqFKoKWtTHNY9AcTLmUwUAYDVR0fBEkwRzBFoEOgQYY/aHR0cDovL2Ny -->
<!-- bC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvbWljcm9zb2Z0cm9vdGNl -->
<!-- cnQuY3JsMFQGCCsGAQUFBwEBBEgwRjBEBggrBgEFBQcwAoY4aHR0cDovL3d3dy5t -->
<!-- aWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNyb3NvZnRSb290Q2VydC5jcnQwdgYD -->
<!-- VR0gBG8wbTBrBgkrBgEEAYI3FS8wXjBcBggrBgEFBQcCAjBQHk4AQwBvAHAAeQBy -->
<!-- AGkAZwBoAHQAIACpACAAMgAwADAANgAgAE0AaQBjAHIAbwBzAG8AZgB0ACAAQwBv -->
<!-- AHIAcABvAHIAYQB0AGkAbwBuAC4wEwYDVR0lBAwwCgYIKwYBBQUHAwMwDQYJKoZI -->
<!-- hvcNAQEFBQADggIBADC8sCCkYqCn7zkmYT3crMaZ0IbELvWDMmVeIj6b1ob46Laf -->
<!-- yovWO3ULoZE+TN1kdIxJ8oiMGGds/hVmRrg6RkKXyJE31CSx56zT6kEUg3fTyU8F -->
<!-- X6MUUr+WpC8+VlsQdc5Tw84FVGm0ZckkpQ/hJbgauU3lArlQHk+zmAwdlQLuIlmt -->
<!-- IssFdAsERXsEWeDYD7PrTPhg3cJ4ntG6n2v38+5+RBFA0r26m0sWCG6kvlXkpjgS -->
<!-- o0j0HFV6iiDRff6R25SPL8J7a6ZkhU+j5Sw0KV0Lv/XHOC/EIMRWMfZpzoX4CpHs -->
<!-- 0NauujgFDOtuT0ycAymqovwYoCkMDVxcViNX2hyWDcgmNsFEy+Xh5m+J54/pmLVz -->
<!-- 03jj7aMBPHTlXrxs9iGJZwXsl521sf2vpulypcM04S+f+fRqOeItBIJb/NCcrnyd -->
<!-- EfnmtVMZdLo5SjnrfUKzSjs3PcJKeyeY5+JOmxtKVDhqIze+ardI7upCDUkkkY63 -->
<!-- BC6Xb+TnRbuPTf1g2ddZwtiA1mA0e7ehkyD+gbiqpVwJ6YoNvihNftfoD+1leNEx -->
<!-- X7lm299C5wvMAgeN3/8gBqNFZbSzMo0ukeJNtKnJ+rxrBA6yn+qf3qTJCpb0jffY -->
<!-- mKjwhQIIWaQgpiwLGvJSBu1p5WQYG+Cjq97KfBRhQ7hl9TajVRMrZyxNGzBMMYIE -->
<!-- uDCCBLQCAQEwgYcweTELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x -->
<!-- EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv -->
<!-- bjEjMCEGA1UEAxMaTWljcm9zb2Z0IENvZGUgU2lnbmluZyBQQ0ECCmEETEsAAAAA -->
<!-- ACQwCQYFKw4DAhoFAKCB5TAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor -->
<!-- BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUvQElCv6Y -->
<!-- q0eesZV5Z9hsYZPjK7AwgYQGCisGAQQBgjcCAQwxdjB0oEyASgBTAFEATAAgAFMA -->
<!-- ZQByAHYAZQByACAAUABvAHcAZQByAHMAaABlAGwAbAAgAFAAcgBvAHYAaQBkAGUA -->
<!-- cgAgAEYAbwByAG0AYQB0oSSAImh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9zcWxz -->
<!-- ZXJ2ZXIwDQYJKoZIhvcNAQEBBQAEggEAftpotR8sNZnpf+Q1ILkQeG73gr3ODrNF -->
<!-- m5DU2/hmtnBgyW2pZWZ0eOkmM8fX2zLEczINB9hW230qEGxmySMQT1SzsYSmt3Gb -->
<!-- m40+jnnPZ+eDbsEzRHBBoZwv6Sgy/gPfcAxlbJSkP01d/XWDvhpLqwZrj4COpfXl -->
<!-- eUAUjSwPEVFXffgnuTBfuOwziHwtA/ok4cSD9affKq1r/x1zSMvnTJ+SuY+yrfSj -->
<!-- iUJvhBy7S+BQW3F5KCxtrWqmwO5mbVnKxF7wxqKKpuT78xi/pImrCbNm5EwXFZ4N -->
<!-- Znayag4zSUtCv1CLBuI69wI6Evq9lpLU8oaBq2tx91hTTCdGOgFi0KGCAh0wggIZ -->
<!-- BgkqhkiG9w0BCQYxggIKMIICBgIBATCBhTB3MQswCQYDVQQGEwJVUzETMBEGA1UE -->
<!-- CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z -->
<!-- b2Z0IENvcnBvcmF0aW9uMSEwHwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQ -->
<!-- Q0ECCmEEs/UAAAAAAA0wBwYFKw4DAhqgXTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcN -->
<!-- AQcBMBwGCSqGSIb3DQEJBTEPFw0wOTA0MjMwMjU5MzJaMCMGCSqGSIb3DQEJBDEW -->
<!-- BBR0fq0bie0x274v1PrNauygehkYwzANBgkqhkiG9w0BAQUFAASCAQCjuZEUAdO2 -->
<!-- WUtL5BEHJH9xs6y8V+3EPpnxZ4hVbA46g0CWbNV+OYOz+WFyxNs1KylwnHpXf3fS -->
<!-- AkGrqcRHI+RACGystMT073cCWKHfCKUyrIuBFNhD1jR1vLF0Uc5DsRRMO4/HJhUe -->
<!-- tkXYQXT41lQHwPR3BHmMP5uuVVdB6N28ZguowC+2waCrRTvCOq/PRVNmFDKrh1Md -->
<!-- g6CvSlVDPN7e7yXCgCYF/JZof470X75ffUmVLjjeCspoxd8HQoYwTSZIWPQDRWEr -->
<!-- hIwFv032d+lxrZZmmdSUevPme6+jq1KxKgyJXNr0VDe9aQgRnX+Z1kt0TM+v5jlN -->
<!-- +g8LLwfEPCFg -->
<!-- SIG # End signature block -->
