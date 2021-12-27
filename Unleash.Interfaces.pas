unit Unleash.Interfaces;

interface

uses
  System.Generics.Collections;

type
  TUnleashConfig = record
    url: string;
    appName: string;
    instanceId: string;
    prefixFilter: string;
    initialFeaturesJson: string;
    noEtag: Boolean;
    timeout: Integer;
    apiKey: string;
  public
    procedure Default;
  end;

  TUnleashContext = record
    userId: string;
    remoteAddress: string;
    customParam: string;
  end;

  IUnleash = interface
    ['{D1B8C7DD-A665-4FCE-A43C-939FA010B462}']

    procedure SetDefaultContext(const Context: TUnleashContext);

    procedure Initialize(const Configuration: TUnleashConfig);
    function IsEnabled(const ToggleName: string): Boolean; overload;
    function IsEnabled(const ToggleName: string; const Context: TUnleashContext): Boolean; overload;

    procedure Refresh;
    function GetLatestFeaturesJson: string;
    function GetLastError: string;
  end;

implementation

{ TUnleashConfig }

procedure TUnleashConfig.Default;
begin
  noEtag := False;
  timeout := 10000;
end;

end.
