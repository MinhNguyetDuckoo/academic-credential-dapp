import { useState, useEffect } from "react";
import { ethers, BrowserProvider, Contract } from "ethers";
import ContractABI from "../CredentialRegistry.json";
import ContractAddress from "../contract-address.json";

export function useContract() {
  const [provider, setProvider]   = useState<BrowserProvider | null>(null);
  const [contract, setContract]   = useState<Contract | null>(null);
  const [account,  setAccount]    = useState<string>("");
  const [isIssuer, setIsIssuer]   = useState<boolean>(false);

  const connect = async () => {
    if (!window.ethereum) {
      alert("Vui lòng cài MetaMask!");
      return;
    }
    const _provider = new ethers.BrowserProvider(window.ethereum);
    await _provider.send("eth_requestAccounts", []);
    const signer = await _provider.getSigner();
    const addr   = await signer.getAddress();

    const _contract = new ethers.Contract(
      ContractAddress.CredentialRegistry,
      ContractABI.abi,
      signer
    );

    const _isIssuer = await _contract.authorizedIssuers(addr);

    setProvider(_provider);
    setContract(_contract);
    setAccount(addr);
    setIsIssuer(_isIssuer);
  };

  return { provider, contract, account, isIssuer, connect };
}