unit Unleash.Types;

interface

uses
  System.Classes,
  System.Generics.Collections;

type
  TUnleashStrategy = class
  public
    Name: string;
    Ids: TStrings;
    Percentage: Integer;

    constructor Create;
    destructor Destroy; override;

    function IsInIds(const Id: string): Boolean;
  end;

  TUnleashFeature = class
  public
    Name: string;
    Description: string;
    Enabled: Boolean;
    Strategies: TList<TUnleashStrategy>;

    constructor Create;
    destructor Destroy; override;
  end;

implementation

{ TUnleashStrategy }

constructor TUnleashStrategy.Create;
begin
  Ids := TStringList.Create;
end;

destructor TUnleashStrategy.Destroy;
begin
  Ids.Free;

  inherited;
end;

function TUnleashStrategy.IsInIds(const Id: string): Boolean;
begin
  Result := Ids.IndexOf(Id) <> -1;
end;

{ TUnleashFeature }

constructor TUnleashFeature.Create;
begin
  Strategies := TObjectList<TUnleashStrategy>.Create;
end;

destructor TUnleashFeature.Destroy;
begin
  Strategies.Free;

  inherited;
end;

end.
