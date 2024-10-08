
// Importing necessary functionalities from the Hardhat package.
import { ethers } from 'hardhat'

async function main() {
    // Retrieve the first signer, typically the default account in Hardhat, to use as the deployer.
    const [deployer] = await ethers.getSigners()
    const WrappedFriendtech = await ethers.getContractFactory("WrappedFriendtech");
    const wrappedFriendtech = await WrappedFriendtech.deploy(deployer);
    await wrappedFriendtech.waitForDeployment();
    console.log(`wrappedFriendtech contract is deployed. Contract address: ${wrappedFriendtech.target}`)

    
}

// This pattern allows the use of async/await throughout and ensures that errors are caught and handled properly.
main().catch(error => {
    console.error(error)
    process.exitCode = 1
})