

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const LansellerModule = buildModule("LansellerModule", (m: any) => {
 
  // Deploy LanSeller with token address and price feed
  const Token = m.contract("Token");
  const verifier = m.contract("Verifier");
  const lanSeller = m.contract("LanSeller", [Token, verifier]);

  return { Token, verifier, lanSeller };
});

export default LansellerModule;