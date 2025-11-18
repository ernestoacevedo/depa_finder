import { useState } from 'react'

function App() {
  const [count, setCount] = useState(0)

  return (
    <div className="App">
      <header className="App-header">
        <h1>Depa Finder</h1>
        <p>Rental listing scraper with real-time notifications</p>
        
        <div className="card">
          <button onClick={() => setCount((count) => count + 1)}>
            Count is {count}
          </button>
          <p>
            This is a placeholder for the React frontend. 
            Follow the constitutional requirements for spec-driven development.
          </p>
        </div>
        
        <p className="read-the-docs">
          Start by creating specifications with <code>/speckit.specify</code>
        </p>
      </header>
    </div>
  )
}

export default App
