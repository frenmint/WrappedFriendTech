
// Importing necessary functionalities from the Hardhat package.
import { ethers } from 'hardhat'

async function main() {
    // Retrieve the first signer, typically the default account in Hardhat, to use as the deployer.
    const [deployer] = await ethers.getSigners()
    
    const instance = await ethers.getContractFactory('FriendtechSharesV1');
    const FriendtechSharesV1 = await instance.deploy();
    await FriendtechSharesV1.waitForDeployment();
    console.log(`FriendtechSharesV1 contract is deployed. Contract address: ${FriendtechSharesV1.target}`)
    
}

// This pattern allows the use of async/await throughout and ensures that errors are caught and handled properly.
main().catch(error => {
    console.error(error)
    process.exitCode = 1
})